"""Analysis endpoints — Phase 1 (BUILD_PLAN §1).

POST /analysis/body        image + height_cm → BodyProfile
POST /analysis/appearance  image → ColorProfile
GET  /models               backend ModelManager status report

Image bytes stay in request memory; they are never written to disk and never
logged (BUILD_PLAN §5).
"""

from fastapi import APIRouter, File, Form, HTTPException, UploadFile

from app.models.manager import RegistryEntryError, manager
from app.services import appearance_service, body_service

router = APIRouter()

MAX_IMAGE_BYTES = 15 * 1024 * 1024
MIN_HEIGHT_CM, MAX_HEIGHT_CM = 100.0, 250.0


async def _read_image(file: UploadFile) -> bytes:
    data = await file.read()
    if not data:
        raise HTTPException(status_code=422, detail="Empty image upload.")
    if len(data) > MAX_IMAGE_BYTES:
        raise HTTPException(status_code=413, detail="Image exceeds 15 MB.")
    return data


@router.post("/analysis/body")
async def analysis_body(file: UploadFile = File(...), height_cm: float = Form(...)) -> dict:
    if not (MIN_HEIGHT_CM <= height_cm <= MAX_HEIGHT_CM):
        raise HTTPException(
            status_code=422,
            detail=f"height_cm must be between {MIN_HEIGHT_CM:.0f} and {MAX_HEIGHT_CM:.0f}.",
        )
    data = await _read_image(file)
    return body_service.analyze_body(data, height_cm)


@router.post("/analysis/appearance")
async def analysis_appearance(file: UploadFile = File(...)) -> dict:
    data = await _read_image(file)
    return appearance_service.analyze_appearance(data)


@router.get("/models")
async def models_status() -> dict:
    try:
        manager.discover()
    except RegistryEntryError as exc:
        raise HTTPException(status_code=503, detail=str(exc))
    return {"models": manager.report()}
