from sqlalchemy import Column, String, Enum, DateTime, ForeignKey, JSON
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func
import uuid
import enum
from database import Base


class PrescriptionStatus(str, enum.Enum):
    pending = "pending"
    approved = "approved"
    rejected = "rejected"


class Prescription(Base):
    __tablename__ = "prescriptions"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    doctor_id = Column(UUID(as_uuid=True), ForeignKey("doctor_profiles.id"), nullable=False)
    patient_id = Column(UUID(as_uuid=True), ForeignKey("patient_profiles.id"), nullable=False)
    medicine_id = Column(UUID(as_uuid=True), ForeignKey("medicines.id"), nullable=False)
    dosage = Column(String)
    frequency = Column(String)
    duration = Column(String)
    notes = Column(String)
    ddi_check_result = Column(JSON)          # full DDI result stored for audit
    status = Column(Enum(PrescriptionStatus), default=PrescriptionStatus.approved)
    prescribed_at = Column(DateTime(timezone=True), server_default=func.now())

    doctor = relationship("DoctorProfile")
    patient = relationship("PatientProfile")
    medicine = relationship("Medicine")
