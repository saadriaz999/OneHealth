from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from database import engine, Base
from routers import auth, patient, doctor

# Import all models so SQLAlchemy creates tables
import models  # noqa: F401

Base.metadata.create_all(bind=engine)

app = FastAPI(
    title="OneHealth API",
    description="AI-powered drug interaction and medication management platform",
    version="1.0.0",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(auth.router)
app.include_router(patient.router)
app.include_router(doctor.router)


@app.get("/health")
def health_check():
    return {"status": "ok", "service": "OneHealth API"}
