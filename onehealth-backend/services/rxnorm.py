import httpx
from typing import Optional

RXNORM_BASE = "https://rxnav.nlm.nih.gov/REST"


async def get_rxcui(drug_name: str) -> Optional[str]:
    """Get RxNorm concept unique identifier for a drug name."""
    async with httpx.AsyncClient() as client:
        resp = await client.get(
            f"{RXNORM_BASE}/rxcui.json",
            params={"name": drug_name, "search": 1}
        )
        data = resp.json()
        id_group = data.get("idGroup", {})
        rxnorm_ids = id_group.get("rxnormId", [])
        return rxnorm_ids[0] if rxnorm_ids else None


async def get_drug_info(rxcui: str) -> dict:
    """Get full drug info from RxNorm by rxcui."""
    async with httpx.AsyncClient() as client:
        resp = await client.get(f"{RXNORM_BASE}/rxcui/{rxcui}/properties.json")
        data = resp.json()
        props = data.get("properties", {})
        return {
            "rxcui": rxcui,
            "name": props.get("name"),
            "synonym": props.get("synonym"),
            "tty": props.get("tty"),      # term type: brand, generic, etc.
            "language": props.get("language"),
        }


async def get_related_drugs(rxcui: str) -> list:
    """Get related brand/generic names for a drug."""
    async with httpx.AsyncClient() as client:
        resp = await client.get(
            f"{RXNORM_BASE}/rxcui/{rxcui}/related.json",
            params={"tty": "BN+IN+PIN"}
        )
        data = resp.json()
        groups = data.get("relatedGroup", {}).get("conceptGroup", [])
        results = []
        for group in groups:
            for concept in group.get("conceptProperties", []):
                results.append({
                    "rxcui": concept.get("rxcui"),
                    "name": concept.get("name"),
                    "tty": concept.get("tty"),
                })
        return results


async def normalize_drug_name(drug_name: str) -> dict:
    """Full normalization: name → rxcui → structured info."""
    rxcui = await get_rxcui(drug_name)
    if not rxcui:
        return {"rxcui": None, "name": drug_name, "normalized": False}

    info = await get_drug_info(rxcui)
    info["normalized"] = True
    return info
