from sqlalchemy import Column, String, Enum, DateTime, ForeignKey, Integer
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func
import uuid
import enum
from database import Base


class AddedBy(str, enum.Enum):
    patient = "patient"
    doctor = "doctor"


class PatientMedicine(Base):
    __tablename__ = "patient_medicines"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    patient_id = Column(UUID(as_uuid=True), ForeignKey("patient_profiles.id"), nullable=False)
    medicine_id = Column(UUID(as_uuid=True), ForeignKey("medicines.id"), nullable=False)
    dosage = Column(String)
    frequency = Column(String)               # e.g. "twice daily"
    times_per_day = Column(Integer)
    time_of_day = Column(String)             # e.g. "morning, evening"
    start_date = Column(String)
    notes = Column(String)
    added_by = Column(Enum(AddedBy), default=AddedBy.patient)
    created_at = Column(DateTime(timezone=True), server_default=func.now())

    patient = relationship("PatientProfile", back_populates="medicines")
    medicine = relationship("Medicine", back_populates="patient_medicines")
