"""Phase 4 virtual try-on router — thin, like routers/analysis.py.

POST /tryon/render  person photo + garment photo → labeled render or §12 state.
Image bytes stay in request memory; they are never written to disk or logged.
"""

from fastapi import APIRouter, File, HTTPException, UploadFile

from app.services import vton_service

router = APIRouter()


async def _read_image(file: UploadFile) -> bytes:
    data = await file.read()
    if not data:
        raise HTTPException(status_code=422, detail="Empty image upload.")
    return data


@router.post("/tryon/render")
async def tryon_render(
    person: UploadFile = File(...), garment: UploadFile = File(...)
) -> dict:
    person_bytes = await _read_image(person)
    garment_bytes = await _read_image(garment)
    return await vton_service.render_tryon(person_bytes, garment_bytes)
