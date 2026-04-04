import anthropic
import base64
import json
from typing import Optional
from config import get_settings

settings = get_settings()
client = anthropic.Anthropic(api_key=settings.anthropic_api_key)


async def extract_medicine_from_image(image_bytes: bytes, mime_type: str = "image/jpeg") -> dict:
    """
    Extract medicine details from a packaging photo.
    Returns structured drug info extracted by Claude Vision.
    """
    image_b64 = base64.standard_b64encode(image_bytes).decode("utf-8")

    message = client.messages.create(
        model="claude-sonnet-4-6",
        max_tokens=1024,
        messages=[
            {
                "role": "user",
                "content": [
                    {
                        "type": "image",
                        "source": {
                            "type": "base64",
                            "media_type": mime_type,
                            "data": image_b64,
                        },
                    },
                    {
                        "type": "text",
                        "text": (
                            "This is a medicine packaging photo. Extract the following information and return ONLY valid JSON with no extra text:\n"
                            "{\n"
                            '  "brand_name": "string or null",\n'
                            '  "generic_name": "string or null",\n'
                            '  "dosage_strength": "string or null (e.g. 500mg)",\n'
                            '  "dosage_form": "string or null (e.g. tablet, capsule, syrup)",\n'
                            '  "manufacturer": "string or null",\n'
                            '  "active_ingredients": ["list of strings"],\n'
                            '  "instructions": "string or null",\n'
                            '  "is_international": true or false,\n'
                            '  "country_of_origin": "string or null"\n'
                            "}"
                        ),
                    },
                ],
            }
        ],
    )

    raw = message.content[0].text.strip()
    try:
        return json.loads(raw)
    except json.JSONDecodeError:
        # If Claude wrapped in markdown, strip it
        if "```" in raw:
            raw = raw.split("```")[1]
            if raw.startswith("json"):
                raw = raw[4:]
        return json.loads(raw.strip())


async def explain_ddi(interactions: list, patient_context: Optional[str] = None) -> str:
    """
    Explain DDI results in plain language for a patient.
    interactions: list of DDI dicts from DrugBank/DDInter.
    """
    if not interactions:
        return "No drug interactions were found between your current medications."

    interaction_text = "\n".join([
        f"- {i.get('drug_a_name', i.get('drug_a', 'Drug A'))} + "
        f"{i.get('drug_b_name', i.get('drug_b', 'Drug B'))}: "
        f"[{i.get('severity', 'unknown').upper()}] {i.get('description', '')}"
        for i in interactions
    ])

    context_note = f"\nPatient context: {patient_context}" if patient_context else ""

    message = client.messages.create(
        model="claude-sonnet-4-6",
        max_tokens=512,
        messages=[
            {
                "role": "user",
                "content": (
                    f"You are a helpful medical assistant. Explain the following drug interactions "
                    f"in simple, clear language that a non-medical patient can understand. "
                    f"Be concise but informative. Mention severity and what to watch out for.{context_note}\n\n"
                    f"Drug interactions found:\n{interaction_text}"
                ),
            }
        ],
    )
    return message.content[0].text


async def explain_ddi_for_doctor(interactions: list) -> str:
    """
    Explain DDI results in clinical language for a doctor.
    """
    if not interactions:
        return "No clinically significant drug interactions identified."

    interaction_text = "\n".join([
        f"- {i.get('drug_a_name', i.get('drug_a', 'Drug A'))} + "
        f"{i.get('drug_b_name', i.get('drug_b', 'Drug B'))}: "
        f"[{i.get('severity', 'unknown').upper()}] {i.get('description', '')} "
        f"Management: {i.get('management', 'N/A')}"
        for i in interactions
    ])

    message = client.messages.create(
        model="claude-sonnet-4-6",
        max_tokens=512,
        messages=[
            {
                "role": "user",
                "content": (
                    f"You are a clinical decision support system. Summarize the following drug-drug interactions "
                    f"for a prescribing physician. Include mechanism, clinical significance, and management recommendations. "
                    f"Be concise and clinically precise.\n\n"
                    f"Interactions:\n{interaction_text}"
                ),
            }
        ],
    )
    return message.content[0].text


async def patient_chatbot(
    message: str,
    patient_medicines: list,
    conversation_history: list
) -> str:
    """
    LLM chatbot for patient questions about their medicines.
    patient_medicines: list of medicine names the patient is taking.
    conversation_history: list of prior {"role": ..., "content": ...} messages.
    """
    medicines_context = ", ".join(patient_medicines) if patient_medicines else "none on file"

    system_prompt = (
        f"You are a helpful and empathetic medical assistant for a patient. "
        f"The patient is currently taking: {medicines_context}. "
        f"Answer their questions about their medicines clearly and safely. "
        f"Always recommend consulting their doctor for medical decisions. "
        f"Never diagnose or prescribe. Be supportive and easy to understand."
    )

    messages = conversation_history + [{"role": "user", "content": message}]

    response = client.messages.create(
        model="claude-sonnet-4-6",
        max_tokens=512,
        system=system_prompt,
        messages=messages,
    )
    return response.content[0].text


async def describe_international_drug(drug_name: str, active_ingredients: list) -> str:
    """
    Generate a clinical description of a foreign/international drug for a doctor.
    """
    ingredients_text = ", ".join([
        f"{i.get('name', '')} {i.get('strength', '')} {i.get('unit', '')}"
        for i in active_ingredients
    ]) if active_ingredients else "unknown"

    message = client.messages.create(
        model="claude-sonnet-4-6",
        max_tokens=512,
        messages=[
            {
                "role": "user",
                "content": (
                    f"You are a clinical pharmacology assistant. A doctor needs information about a foreign medicine "
                    f"called '{drug_name}' with active ingredients: {ingredients_text}. "
                    f"Provide a brief clinical summary: drug class, mechanism of action, common uses, "
                    f"and any important safety considerations. Keep it concise and clinical."
                ),
            }
        ],
    )
    return message.content[0].text
