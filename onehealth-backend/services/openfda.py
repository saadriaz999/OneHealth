import httpx

OPENFDA_BASE = "https://api.fda.gov/drug"


async def get_adverse_events(drug_name: str, limit: int = 10) -> list:
    """Get adverse event reports for a drug from FDA FAERS database."""
    async with httpx.AsyncClient() as client:
        resp = await client.get(
            f"{OPENFDA_BASE}/event.json",
            params={
                "search": f'patient.drug.medicinalproduct:"{drug_name}"',
                "limit": limit,
            }
        )
        if resp.status_code != 200:
            return []
        data = resp.json()
        results = data.get("results", [])

        events = []
        for r in results:
            reactions = [
                rx.get("reactionmeddrapt", "")
                for rx in r.get("patient", {}).get("reaction", [])
            ]
            events.append({
                "reactions": reactions,
                "serious": r.get("serious"),
                "report_date": r.get("receiptdate"),
            })
        return events


async def get_drug_label(drug_name: str) -> dict:
    """Get drug label info from FDA."""
    async with httpx.AsyncClient() as client:
        resp = await client.get(
            f"{OPENFDA_BASE}/label.json",
            params={
                "search": f'openfda.brand_name:"{drug_name}"',
                "limit": 1,
            }
        )
        if resp.status_code != 200:
            return {}
        data = resp.json()
        results = data.get("results", [])
        if not results:
            return {}

        label = results[0]
        return {
            "brand_name": label.get("openfda", {}).get("brand_name", []),
            "generic_name": label.get("openfda", {}).get("generic_name", []),
            "manufacturer": label.get("openfda", {}).get("manufacturer_name", []),
            "warnings": label.get("warnings", []),
            "contraindications": label.get("contraindications", []),
            "drug_interactions": label.get("drug_interactions", []),
        }
