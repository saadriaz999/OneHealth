from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from pydantic import BaseModel
from typing import Optional
from database import get_db
from auth.rbac import require_doctor
from models.user import User, DoctorProfile, PatientProfile
from models.medicine import Medicine
from models.patient_medicine import PatientMedicine, AddedBy
from models.prescription import Prescription
from services import llm, rxnorm, drugbank, ddinter, dailymed, openfda
import uuid

router = APIRouter(prefix="/doctor", tags=["Doctor"])


# ── Schemas ──────────────────────────────────────────────────────────────────

class PrescribeRequest(BaseModel):
    patient_id: str
    medicine_name: str
    generic_name: Optional[str] = None
    dosage: Optional[str] = None
    frequency: Optional[str] = None
    duration: Optional[str] = None
    notes: Optional[str] = None
    force: bool = False     # override warning and prescribe anyway


class AssignPatientRequest(BaseModel):
    patient_email: str


# ── Helpers ──────────────────────────────────────────────────────────────────

def get_doctor_profile(user: User, db: Session) -> DoctorProfile:
    profile = db.query(DoctorProfile).filter(DoctorProfile.user_id == user.id).first()
    if not profile:
        raise HTTPException(status_code=404, detail="Doctor profile not found")
    return profile


async def resolve_medicine(name: str, generic_name: str, db: Session) -> Medicine:
    normalized = await rxnorm.normalize_drug_name(name)
    rxcui = normalized.get("rxcui")

    query = db.query(Medicine)
    existing = query.filter(Medicine.rxnorm_id == rxcui).first() if rxcui else query.filter(Medicine.name.ilike(name)).first()
    if existing:
        return existing

    db_id = await drugbank.get_drugbank_id(generic_name or name)
    medicine = Medicine(
        name=name,
        generic_name=generic_name or normalized.get("name"),
        rxnorm_id=rxcui,
        drugbank_id=db_id,
    )
    db.add(medicine)
    db.commit()
    db.refresh(medicine)
    return medicine


# ── Routes ───────────────────────────────────────────────────────────────────

@router.post("/patients/assign")
def assign_patient(
    req: AssignPatientRequest,
    current_user: User = Depends(require_doctor),
    db: Session = Depends(get_db),
):
    """Link a patient to this doctor by patient email."""
    doctor_profile = get_doctor_profile(current_user, db)

    patient_user = db.query(User).filter(User.email == req.patient_email).first()
    if not patient_user:
        raise HTTPException(status_code=404, detail="Patient not found")

    patient_profile = db.query(PatientProfile).filter(PatientProfile.user_id == patient_user.id).first()
    if not patient_profile:
        raise HTTPException(status_code=404, detail="Patient profile not found")

    patient_profile.doctor_id = doctor_profile.id
    db.commit()
    return {"message": f"Patient {patient_user.name} assigned to your account"}


@router.get("/patients")
def get_patients(
    current_user: User = Depends(require_doctor),
    db: Session = Depends(get_db),
):
    """Get all patients assigned to this doctor."""
    doctor_profile = get_doctor_profile(current_user, db)
    patients = (
        db.query(PatientProfile)
        .filter(PatientProfile.doctor_id == doctor_profile.id)
        .all()
    )

    return {
        "patients": [
            {
                "patient_id": str(p.id),
                "user_id": str(p.user_id),
                "name": p.user.name,
                "email": p.user.email,
                "date_of_birth": p.date_of_birth,
                "allergies": p.allergies,
            }
            for p in patients
        ]
    }


@router.get("/patients/{patient_id}/medicines")
def get_patient_medicines(
    patient_id: str,
    current_user: User = Depends(require_doctor),
    db: Session = Depends(get_db),
):
    """Get all medicines for a specific patient."""
    doctor_profile = get_doctor_profile(current_user, db)

    patient_profile = db.query(PatientProfile).filter(
        PatientProfile.id == patient_id,
        PatientProfile.doctor_id == doctor_profile.id,
    ).first()
    if not patient_profile:
        raise HTTPException(status_code=404, detail="Patient not found or not assigned to you")

    entries = db.query(PatientMedicine).filter(PatientMedicine.patient_id == patient_profile.id).all()

    return {
        "patient": patient_profile.user.name,
        "medicines": [
            {
                "id": str(e.id),
                "name": e.medicine.name,
                "generic_name": e.medicine.generic_name,
                "dosage": e.dosage,
                "frequency": e.frequency,
                "times_per_day": e.times_per_day,
                "start_date": e.start_date,
                "added_by": e.added_by,
                "rxnorm_id": e.medicine.rxnorm_id,
                "drugbank_id": e.medicine.drugbank_id,
                "is_international": e.medicine.is_international,
            }
            for e in entries
        ],
    }


@router.post("/prescribe")
async def prescribe(
    req: PrescribeRequest,
    current_user: User = Depends(require_doctor),
    db: Session = Depends(get_db),
):
    """
    Prescribe a medicine to a patient.
    Automatically runs DDI check against all current patient medications.
    Returns warnings if interactions found — doctor must confirm with force=true to override.
    """
    doctor_profile = get_doctor_profile(current_user, db)

    patient_profile = db.query(PatientProfile).filter(
        PatientProfile.id == req.patient_id,
        PatientProfile.doctor_id == doctor_profile.id,
    ).first()
    if not patient_profile:
        raise HTTPException(status_code=404, detail="Patient not found or not assigned to you")

    # Resolve the new medicine
    new_medicine = await resolve_medicine(req.medicine_name, req.generic_name, db)

    # Get patient's current medicines
    current_entries = db.query(PatientMedicine).filter(
        PatientMedicine.patient_id == patient_profile.id
    ).all()
    current_names = [e.medicine.name for e in current_entries]
    current_drugbank_ids = [e.medicine.drugbank_id for e in current_entries if e.medicine.drugbank_id]

    # ── DDI Check ────────────────────────────────────────────────────────────
    interactions = []

    if new_medicine.drugbank_id and current_drugbank_ids:
        all_ids = current_drugbank_ids + [new_medicine.drugbank_id]
        db_interactions = await drugbank.check_ddi(all_ids)
        interactions += [
            i for i in db_interactions
            if i.get("drug_a_id") == new_medicine.drugbank_id
            or i.get("drug_b_id") == new_medicine.drugbank_id
        ]

    # DDInter as backup
    for current_name in current_names:
        ddinter_result = await ddinter.check_ddi(req.medicine_name, current_name)
        if ddinter_result and ddinter_result.get("interaction"):
            interactions.append({
                "drug_a": req.medicine_name,
                "drug_b": current_name,
                "severity": ddinter_result.get("level", "unknown"),
                "description": ddinter_result.get("description", ""),
                "management": ddinter_result.get("management", ""),
                "source": "DDInter 2.0",
            })

    has_major = any(i.get("severity") in ["major", "contraindicated"] for i in interactions)

    # Block if major/contraindicated interaction and doctor didn't force override
    if has_major and not req.force:
        explanation = await llm.explain_ddi_for_doctor(interactions)
        return {
            "status": "blocked",
            "message": "Major or contraindicated drug interaction detected. Review interactions and set force=true to override.",
            "interactions": interactions,
            "clinical_summary": explanation,
        }

    # Generate clinical summary
    clinical_summary = await llm.explain_ddi_for_doctor(interactions) if interactions else None

    # Save prescription
    prescription = Prescription(
        doctor_id=doctor_profile.id,
        patient_id=patient_profile.id,
        medicine_id=new_medicine.id,
        dosage=req.dosage,
        frequency=req.frequency,
        duration=req.duration,
        notes=req.notes,
        ddi_check_result={
            "interactions": interactions,
            "clinical_summary": clinical_summary,
            "forced_override": req.force and has_major,
        },
    )
    db.add(prescription)

    # Also add to patient's active medicines
    patient_entry = PatientMedicine(
        patient_id=patient_profile.id,
        medicine_id=new_medicine.id,
        dosage=req.dosage,
        frequency=req.frequency,
        notes=req.notes,
        added_by=AddedBy.doctor,
    )
    db.add(patient_entry)
    db.commit()

    return {
        "status": "prescribed",
        "medicine": req.medicine_name,
        "patient": patient_profile.user.name,
        "interactions_found": len(interactions),
        "interactions": interactions,
        "clinical_summary": clinical_summary,
        "warning": "Interaction overridden by doctor" if req.force and has_major else None,
    }


@router.get("/medicines/international-lookup")
async def international_lookup(
    name: str,
    current_user: User = Depends(require_doctor),
):
    """
    Look up a foreign/international medicine.
    Returns: active ingredients, drug class, clinical description, US equivalents.
    """
    # Get active ingredients from DailyMed
    ingredients = await dailymed.get_active_ingredients(name)

    # Get US equivalents
    equivalents = await dailymed.find_us_equivalent(name)

    # Get OpenFDA label data
    fda_label = await openfda.get_drug_label(name)

    # LLM clinical description
    description = await llm.describe_international_drug(name, ingredients)

    return {
        "drug_name": name,
        "active_ingredients": ingredients,
        "clinical_description": description,
        "us_equivalents": equivalents.get("equivalents", []),
        "fda_label": fda_label,
    }


@router.get("/medicines/us-equivalent")
async def us_equivalent(
    name: str,
    current_user: User = Depends(require_doctor),
):
    """Find US equivalent for a foreign drug by active ingredient matching."""
    result = await dailymed.find_us_equivalent(name)
    return result


@router.get("/prescriptions/{patient_id}")
def get_prescriptions(
    patient_id: str,
    current_user: User = Depends(require_doctor),
    db: Session = Depends(get_db),
):
    """Get prescription history for a patient."""
    doctor_profile = get_doctor_profile(current_user, db)

    prescriptions = (
        db.query(Prescription)
        .filter(
            Prescription.patient_id == patient_id,
            Prescription.doctor_id == doctor_profile.id,
        )
        .order_by(Prescription.prescribed_at.desc())
        .all()
    )

    return {
        "prescriptions": [
            {
                "id": str(p.id),
                "medicine": p.medicine.name,
                "dosage": p.dosage,
                "frequency": p.frequency,
                "duration": p.duration,
                "prescribed_at": str(p.prescribed_at),
                "ddi_check_result": p.ddi_check_result,
            }
            for p in prescriptions
        ]
    }
