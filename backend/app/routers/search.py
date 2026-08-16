"""Phase 8 Find-This-Look router — thin, like routers/tryon.py.

POST /search/similar  query photo + the client's real wardrobe embeddings
→ tiered matches or NO_MATCH_FOUND. The query image stays in request memory.
"""

import json

from fastapi import APIRouter, File, Form, HTTPException, UploadFile

from app.services import search_service

router = APIRouter()

EMBEDDING_DIM = 512


def _parse_candidates(raw: str) -> list[dict]:
    try:
        parsed = json.loads(raw)
    except json.JSONDecodeError as exc:
        raise HTTPException(status_code=422, detail="candidates must be valid JSON.") from exc
    if not isinstance(parsed, list):
        raise HTTPException(status_code=422, detail="candidates must be a list.")
    out = []
    for entry in parsed:
        if not isinstance(entry, dict):
            raise HTTPException(status_code=422, detail="each candidate must be an object.")
        item_id = entry.get("id")
        embedding = entry.get("embedding")
        if not isinstance(item_id, str) or not item_id:
            raise HTTPException(status_code=422, detail="each candidate needs an id.")
        if (
            not isinstance(embedding, list)
            or len(embedding) != EMBEDDING_DIM
            or not all(isinstance(x, (int, float)) for x in embedding)
        ):
            raise HTTPException(
                status_code=422,
                detail=f"candidate {item_id}: embedding must be {EMBEDDING_DIM} numbers.",
            )
        out.append({"id": item_id, "embedding": [float(x) for x in embedding]})
    return out


@router.post("/search/similar")
async def search_similar(
    file: UploadFile = File(...),
    candidates: str = Form("[]"),
) -> dict:
    data = await file.read()
    if not data:
        raise HTTPException(status_code=422, detail="Empty image upload.")
    return search_service.search_similar(data, _parse_candidates(candidates))
