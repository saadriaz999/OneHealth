import httpx
from typing import Optional

DDINTER_BASE = "https://ddinter2.scbdd.com/api"


async def check_ddi(drug_a: str, drug_b: str) -> Optional[dict]:
    """
    Check DDI between two drugs using DDInter 2.0.
    drug_a, drug_b: drug names or DDInter IDs.
    """
    async with httpx.AsyncClient(timeout=15.0) as client:
        resp = await client.get(
            f"{DDINTER_BASE}/ddi-check/",
            params={"drug_a": drug_a, "drug_b": drug_b}
        )
        if resp.status_code != 200:
            return None
        return resp.json()


async def check_ddi_multi(drug_names: list[str]) -> list:
    """
    Check DDI across a list of drugs.
    Returns all pairwise interactions found.
    """
    interactions = []
    checked_pairs = set()

    for i, drug_a in enumerate(drug_names):
        for drug_b in drug_names[i + 1:]:
            pair = tuple(sorted([drug_a.lower(), drug_b.lower()]))
            if pair in checked_pairs:
                continue
            checked_pairs.add(pair)

            result = await check_ddi(drug_a, drug_b)
            if result and result.get("interaction"):
                interactions.append({
                    "drug_a": drug_a,
                    "drug_b": drug_b,
                    "severity": result.get("level", "unknown"),
                    "description": result.get("description", ""),
                    "mechanism": result.get("mechanism", ""),
                    "management": result.get("management", ""),
                    "source": "DDInter 2.0",
                })

    return interactions


async def search_drug(drug_name: str) -> list:
    """Search DDInter for a drug."""
    async with httpx.AsyncClient(timeout=15.0) as client:
        resp = await client.get(
            f"{DDINTER_BASE}/drug-search/",
            params={"name": drug_name}
        )
        if resp.status_code != 200:
            return []
        data = resp.json()
        return data.get("results", [])
