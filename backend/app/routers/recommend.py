"""Phase 3 recommendation router — thin, like routers/analysis.py."""

from fastapi import APIRouter
from pydantic import BaseModel, Field, field_validator

from app.services import occasion_service as occ
from app.services import recommendation_service

router = APIRouter()


class LocationIn(BaseModel):
    latitude: float = Field(ge=-90, le=90)
    longitude: float = Field(ge=-180, le=180)
    label: str = ""


class AttributeIn(BaseModel):
    value: str | None
    confidence: float = Field(ge=0.0, le=1.0)


class ColorIn(BaseModel):
    name: str
    hex: str
    share: float = Field(ge=0.0, le=1.0)


class GarmentIn(BaseModel):
    category: AttributeIn
    colors: list[ColorIn]
    colors_source: str
    pattern: AttributeIn
    fit: AttributeIn
    material: AttributeIn


class WardrobeEntryIn(BaseModel):
    id: str
    garment: GarmentIn
    confidence: float = Field(ge=0.0, le=1.0)
    flags: list[str] = []


class StyleProfileIn(BaseModel):
    height_cm: float | None = None
    fit_preference: str = "regular"
    aesthetics: list[str] = []
    banned_colors: list[str] = []
    banned_brands: list[str] = []
    budget_ceiling: float | None = None


class RecommendRequest(BaseModel):
    occasion: str
    location: LocationIn
    body_profile: dict
    color_profile: dict | None = None
    style_profile: StyleProfileIn = StyleProfileIn()
    wardrobe: list[WardrobeEntryIn]

    @field_validator("occasion")
    @classmethod
    def occasion_in_taxonomy(cls, value: str) -> str:
        if value not in occ.OCCASIONS:
            raise ValueError(f"occasion must be one of: {', '.join(occ.OCCASIONS)}")
        return value


@router.post("/recommend/outfit")
async def recommend_outfit(request: RecommendRequest) -> dict:
    return await recommendation_service.recommend(
        occasion=request.occasion,
        location=request.location.model_dump(),
        body_profile=request.body_profile,
        color_profile=request.color_profile,
        style_profile=request.style_profile.model_dump(),
        wardrobe=[
            {
                "id": e.id,
                "garment": e.garment.model_dump(),
                "confidence": e.confidence,
                "flags": e.flags,
            }
            for e in request.wardrobe
        ],
    )
