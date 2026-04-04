from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from pydantic import BaseModel, EmailStr
from database import get_db
from models.user import User, UserRole, DoctorProfile, PatientProfile
from auth.jwt import hash_password, verify_password, create_access_token

router = APIRouter(prefix="/auth", tags=["Auth"])


class RegisterRequest(BaseModel):
    name: str
    email: EmailStr
    password: str
    role: UserRole
    # Doctor only
    license_number: str = None
    specialty: str = None
    # Patient only
    date_of_birth: str = None
    allergies: str = None


class LoginRequest(BaseModel):
    email: EmailStr
    password: str


class AuthResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    role: str
    user_id: str
    name: str


@router.post("/register", response_model=AuthResponse, status_code=status.HTTP_201_CREATED)
def register(req: RegisterRequest, db: Session = Depends(get_db)):
    existing = db.query(User).filter(User.email == req.email).first()
    if existing:
        raise HTTPException(status_code=400, detail="Email already registered")

    user = User(
        name=req.name,
        email=req.email,
        password_hash=hash_password(req.password),
        role=req.role,
    )
    db.add(user)
    db.flush()  # get user.id before commit

    if req.role == UserRole.doctor:
        if not req.license_number:
            raise HTTPException(status_code=400, detail="License number required for doctors")
        profile = DoctorProfile(
            user_id=user.id,
            license_number=req.license_number,
            specialty=req.specialty,
        )
        db.add(profile)

    elif req.role == UserRole.patient:
        profile = PatientProfile(
            user_id=user.id,
            date_of_birth=req.date_of_birth,
            allergies=req.allergies,
        )
        db.add(profile)

    db.commit()
    db.refresh(user)

    token = create_access_token({"sub": str(user.id), "role": user.role})
    return AuthResponse(
        access_token=token,
        role=user.role,
        user_id=str(user.id),
        name=user.name,
    )


@router.post("/login", response_model=AuthResponse)
def login(req: LoginRequest, db: Session = Depends(get_db)):
    user = db.query(User).filter(User.email == req.email).first()
    if not user or not verify_password(req.password, user.password_hash):
        raise HTTPException(status_code=401, detail="Invalid email or password")

    token = create_access_token({"sub": str(user.id), "role": user.role})
    return AuthResponse(
        access_token=token,
        role=user.role,
        user_id=str(user.id),
        name=user.name,
    )
