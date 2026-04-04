from fastapi import APIRouter, Depends, HTTPException, UploadFile, File, status
from sqlalchemy.orm import Session
from pydantic import BaseModel
from typing import Optional
from database import get_db
from auth.rbac import require_patient
from models.user import User, PatientProfile
from models.medicine import Medicine
from models.patient_medicine import PatientMedicine, AddedBy
from services import llm, rxnorm, drugbank, ddinter, openfda
import uuid

router = APIRouter(prefix="/patient", tags=["Patient"])


# ── Schemas ──────────────────────────────────────────────────────────────────

class AddMedicineRequest(BaseModel):
    name: str
    generic_name: Optional[str] = None
    dosage: Optional[str] = None
    frequency: Optional[str] = None
    times_per_day: Optional[int] = None
    time_of_day: Optional[str] = None
    start_date: Optional[str] = None
    notes: Optional[str] = None
    is_international: bool = False


class ChatRequest(BaseModel):
    message: str
    conversation_history: list = []


# ── Helpers ──────────────────────────────────────────────────────────────────

def get_patient_profile(user: User, db: Session) -> PatientProfile:
    profile = db.query(PatientProfile).filter(PatientProfile.user_id == user.id).first()
    if not profile:
        raise HTTPException(status_code=404, detail="Patient profile not found")
    return profile


async def resolve_medicine(name: str, generic_name: str, is_international: bool, db: Session) -> Medicine:
    """Find or create a medicine record, normalized via RxNorm."""
    normalized = await rxnorm.normalize_drug_name(name)
    rxcui = normalized.get("rxcui")

    # Check if already exists in our DB
    query = db.query(Medicine)
    if rxcui:
        existing = query.filter(Medicine.rxnorm_id == rxcui).first()
    else:
        existing = query.filter(Medicine.name.ilike(name)).first()

    if existing:
        return existing

    # Resolve DrugBank ID
    db_id = await drugbank.get_drugbank_id(generic_name or name)

    medicine = Medicine(
        name=name,
        generic_name=generic_name or normalized.get("name"),
        rxnorm_id=rxcui,
        drugbank_id=db_id,
        is_international=is_international,
    )
    db.add(medicine)
    db.commit()
    db.refresh(medicine)
    return medicine


# ── Routes ───────────────────────────────────────────────────────────────────

@router.post("/medicines/scan")
async def scan_medicine(
    file: UploadFile = File(...),
    current_user: User = Depends(require_patient),
):
    """Upload a medicine packaging photo — Claude extracts drug details."""
    if not file.content_type.startswith("image/"):
        raise HTTPException(status_code=400, detail="File must be an image")

    image_bytes = await file.read()
    extracted = await llm.extract_medicine_from_image(image_bytes, file.content_type)
    return {"extracted": extracted}


@router.post("/medicines/add", status_code=status.HTTP_201_CREATED)
async def add_medicine(
    req: AddMedicineRequest,
    current_user: User = Depends(require_patient),
    db: Session = Depends(get_db),
):
    """Add a medicine to the patient's profile."""
    profile = get_patient_profile(current_user, db)
    medicine = await resolve_medicine(req.name, req.generic_name, req.is_international, db)

    entry = PatientMedicine(
        patient_id=profile.id,
        medicine_id=medicine.id,
        dosage=req.dosage,
        frequency=req.frequency,
        times_per_day=req.times_per_day,
        time_of_day=req.time_of_day,
        start_date=req.start_date,
        notes=req.notes,
        added_by=AddedBy.patient,
    )
    db.add(entry)
    db.commit()
    db.refresh(entry)

    return {
        "message": "Medicine added successfully",
        "medicine": {
            "id": str(medicine.id),
            "name": medicine.name,
            "generic_name": medicine.generic_name,
            "rxnorm_id": medicine.rxnorm_id,
        },
    }


@router.get("/medicines")
def get_my_medicines(
    current_user: User = Depends(require_patient),
    db: Session = Depends(get_db),
):
    """Get all medicines for the logged-in patient (dashboard data)."""
    profile = get_patient_profile(current_user, db)
    entries = (
        db.query(PatientMedicine)
        .filter(PatientMedicine.patient_id == profile.id)
        .all()
    )

    return {
        "patient": current_user.name,
        "medicines": [
            {
                "id": str(e.id),
                "medicine_id": str(e.medicine_id),
                "name": e.medicine.name,
                "generic_name": e.medicine.generic_name,
                "dosage": e.dosage,
                "frequency": e.frequency,
                "times_per_day": e.times_per_day,
                "time_of_day": e.time_of_day,
                "start_date": e.start_date,
                "notes": e.notes,
                "added_by": e.added_by,
                "is_international": e.medicine.is_international,
            }
            for e in entries
        ],
    }


@router.post("/medicines/safety-check")
async def safety_check(
    req: AddMedicineRequest,
    current_user: User = Depends(require_patient),
    db: Session = Depends(get_db),
):
    """
    Check if a new OTC medicine is safe to take with current medications.
    Does NOT add the medicine — only checks safety.
    """
    profile = get_patient_profile(current_user, db)

    # Get all drugbank IDs from patient's current medicines
    current_entries = (
        db.query(PatientMedicine)
        .filter(PatientMedicine.patient_id == profile.id)
        .all()
    )
    current_names = [e.medicine.name for e in current_entries]
    current_drugbank_ids = [
        e.medicine.drugbank_id for e in current_entries if e.medicine.drugbank_id
    ]

    # Resolve the new medicine
    new_db_id = await drugbank.get_drugbank_id(req.name)
    new_rxcui = (await rxnorm.normalize_drug_name(req.name)).get("rxcui")

    interactions = []

    # DrugBank DDI check
    if new_db_id and current_drugbank_ids:
        all_ids = current_drugbank_ids + [new_db_id]
        db_interactions = await drugbank.check_ddi(all_ids)
        # Filter only interactions involving the new drug
        interactions += [
            i for i in db_interactions
            if i.get("drug_a_id") == new_db_id or i.get("drug_b_id") == new_db_id
        ]

    # DDInter backup check
    for current_name in current_names:
        ddinter_result = await ddinter.check_ddi(req.name, current_name)
        if ddinter_result and ddinter_result.get("interaction"):
            interactions.append({
                "drug_a": req.name,
                "drug_b": current_name,
                "severity": ddinter_result.get("level", "unknown"),
                "description": ddinter_result.get("description", ""),
                "management": ddinter_result.get("management", ""),
                "source": "DDInter 2.0",
            })

    is_safe = not any(
        i.get("severity") in ["major", "contraindicated"] for i in interactions
    )
    explanation = await llm.explain_ddi(interactions)

    return {
        "medicine_checked": req.name,
        "is_safe": is_safe,
        "interactions_found": len(interactions),
        "interactions": interactions,
        "explanation": explanation,
    }


@router.post("/chat")
async def chat(
    req: ChatRequest,
    current_user: User = Depends(require_patient),
    db: Session = Depends(get_db),
):
    """Patient chatbot — ask questions about your medicines."""
    profile = get_patient_profile(current_user, db)
    entries = db.query(PatientMedicine).filter(PatientMedicine.patient_id == profile.id).all()
    medicine_names = [e.medicine.name for e in entries]

    response = await llm.patient_chatbot(
        message=req.message,
        patient_medicines=medicine_names,
        conversation_history=req.conversation_history,
    )
    return {"response": response}


@router.delete("/medicines/{entry_id}", status_code=status.HTTP_204_NO_CONTENT)
def remove_medicine(
    entry_id: str,
    current_user: User = Depends(require_patient),
    db: Session = Depends(get_db),
):
    """Remove a medicine from patient's profile."""
    profile = get_patient_profile(current_user, db)
    entry = (
        db.query(PatientMedicine)
        .filter(
            PatientMedicine.id == entry_id,
            PatientMedicine.patient_id == profile.id,
        )
        .first()
    )
    if not entry:
        raise HTTPException(status_code=404, detail="Medicine entry not found")
    db.delete(entry)
    db.commit()
