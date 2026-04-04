from sqlalchemy import Column, String, Boolean, DateTime, JSON
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func
import uuid
from database import Base


class Medicine(Base):
    __tablename__ = "medicines"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    name = Column(String, nullable=False)
    generic_name = Column(String)
    rxnorm_id = Column(String, index=True)
    drugbank_id = Column(String, index=True)
    is_international = Column(Boolean, default=False)
    active_ingredients = Column(JSON)          # list of active ingredients
    manufacturer = Column(String)
    dosage_form = Column(String)               # tablet, capsule, liquid, etc.
    strength = Column(String)
    drug_class = Column(String)
    description = Column(String)
    created_at = Column(DateTime(timezone=True), server_default=func.now())

    patient_medicines = relationship("PatientMedicine", back_populates="medicine")
