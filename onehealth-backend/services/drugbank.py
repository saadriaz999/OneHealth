import httpx
from typing import Optional
from config import get_settings

DRUGBANK_BASE = "https://api.drugbankplus.com/v1"


def _headers() -> dict:
    settings = get_settings()
    return {
        "Authorization": settings.drugbank_api_key,
        "Content-Type": "application/json",
    }


async def search_drug(drug_name: str) -> list:
    """Search DrugBank for a drug by name."""
    async with httpx.AsyncClient() as client:
        resp = await client.get(
            f"{DRUGBANK_BASE}/drugs",
            headers=_headers(),
            params={"q": drug_name, "per_page": 5}
        )
        if resp.status_code != 200:
            return []
        return resp.json()


async def get_drug_interactions(drugbank_id: str) -> list:
    """Get all DDI for a specific drug from DrugBank."""
    async with httpx.AsyncClient() as client:
        resp = await client.get(
            f"{DRUGBANK_BASE}/ddi",
            headers=_headers(),
            params={"drugbank_id": drugbank_id}
        )
        if resp.status_code != 200:
            return []
        return resp.json()


async def check_ddi(drug_ids: list[str]) -> list:
    """
    Check DDI between multiple drugs.
    drug_ids: list of DrugBank IDs.
    Returns list of interactions found.
    """
    interactions = []
    checked_pairs = set()

    async with httpx.AsyncClient() as client:
        for i, drug_a in enumerate(drug_ids):
            for drug_b in drug_ids[i + 1:]:
                pair = tuple(sorted([drug_a, drug_b]))
                if pair in checked_pairs:
                    continue
                checked_pairs.add(pair)

                resp = await client.get(
                    f"{DRUGBANK_BASE}/ddi",
                    headers=_headers(),
                    params={"drugbank_id": drug_a, "drugbank_id_2": drug_b}
                )
                if resp.status_code == 200:
                    data = resp.json()
                    for interaction in data:
                        interactions.append({
                            "drug_a_id": drug_a,
                            "drug_b_id": drug_b,
                            "drug_a_name": interaction.get("product_1", {}).get("name"),
                            "drug_b_name": interaction.get("product_2", {}).get("name"),
                            "description": interaction.get("description"),
                            "severity": _normalize_severity(interaction.get("severity", "")),
                            "action": interaction.get("action"),
                        })
    return interactions


def _normalize_severity(raw: str) -> str:
    raw = raw.lower()
    if "contraindicated" in raw:
        return "contraindicated"
    if "major" in raw or "severe" in raw:
        return "major"
    if "moderate" in raw:
        return "moderate"
    return "minor"


async def get_drugbank_id(drug_name: str) -> Optional[str]:
    """Resolve a drug name to a DrugBank ID."""
    results = await search_drug(drug_name)
    if not results:
        return None
    # DrugBank returns list; first result is best match
    first = results[0] if isinstance(results, list) else results.get("data", [{}])[0]
    return first.get("drugbank_id") or first.get("id")
