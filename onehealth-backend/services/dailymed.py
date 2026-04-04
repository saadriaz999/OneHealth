import httpx
from typing import Optional

DAILYMED_BASE = "https://dailymed.nlm.nih.gov/dailymed/services/v2"


async def search_drug(drug_name: str) -> list:
    """Search DailyMed for drug label information."""
    async with httpx.AsyncClient() as client:
        resp = await client.get(
            f"{DAILYMED_BASE}/spls.json",
            params={"drug_name": drug_name, "pagesize": 5}
        )
        data = resp.json()
        return data.get("data", [])


async def get_drug_label(set_id: str) -> dict:
    """Get full drug label by set ID."""
    async with httpx.AsyncClient() as client:
        resp = await client.get(f"{DAILYMED_BASE}/spls/{set_id}.json")
        return resp.json()


async def get_active_ingredients(drug_name: str) -> list:
    """Extract active ingredients for a drug — key for international → US matching."""
    results = await search_drug(drug_name)
    if not results:
        return []

    set_id = results[0].get("setid")
    if not set_id:
        return []

    label = await get_drug_label(set_id)
    data = label.get("data", {})

    ingredients = []
    # DailyMed returns active ingredients in the product section
    for product in data.get("products", []):
        for ingredient in product.get("ingredients", []):
            if ingredient.get("active"):
                ingredients.append({
                    "name": ingredient.get("name"),
                    "strength": ingredient.get("strength"),
                    "unit": ingredient.get("unit"),
                })
    return ingredients


async def find_us_equivalent(foreign_drug_name: str) -> dict:
    """
    Find US equivalent for a foreign drug.
    Strategy: extract active ingredient → search that ingredient in RxNorm → return US brand names.
    """
    ingredients = await get_active_ingredients(foreign_drug_name)
    if not ingredients:
        return {"found": False, "foreign_drug": foreign_drug_name, "equivalents": []}

    primary_ingredient = ingredients[0].get("name", "")

    # Search DailyMed by active ingredient to find US equivalents
    async with httpx.AsyncClient() as client:
        resp = await client.get(
            f"{DAILYMED_BASE}/spls.json",
            params={"drug_name": primary_ingredient, "pagesize": 10}
        )
        data = resp.json()
        equivalents = []
        for item in data.get("data", []):
            equivalents.append({
                "name": item.get("title"),
                "set_id": item.get("setid"),
            })

    return {
        "found": True,
        "foreign_drug": foreign_drug_name,
        "active_ingredient": primary_ingredient,
        "equivalents": equivalents[:5],
    }
