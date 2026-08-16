"""Phase 5 size engine router — thin, like routers/tryon.py.

POST /size/recommend  real body profile + real user-entered size chart
→ recommended size + confidence + per-region breakdown (§8).
"""

from fastapi import APIRouter
from pydantic import BaseModel, Field, field_validator

from app.services import occasion_service as occ
from app.services import size_service

router = APIRouter()


class SizeRowIn(BaseModel):
    label: str = Field(min_length=1, max_length=12)
    chest_cm: float | None = Field(default=None, ge=0, le=300)
    waist_cm: float | None = Field(default=None, ge=0, le=300)
    hip_cm: float | None = Field(default=None, ge=0, le=300)
    shoulder_cm: float | None = Field(default=None, ge=0, le=300)
    sleeve_cm: float | None = Field(default=None, ge=0, le=300)
    length_cm: float | None = Field(default=None, ge=0, le=300)

    def regions(self) -> dict:
        return {
            "chest": self.chest_cm,
            "waist": self.waist_cm,
            "hip": self.hip_cm,
            "shoulder": self.shoulder_cm,
            "sleeve": self.sleeve_cm,
            "length": self.length_cm,
        }


class SizeChartIn(BaseModel):
    brand: str = ""
    rows: list[SizeRowIn]


class SizeRequest(BaseModel):
    category: str
    fit_type: str = "regular"
    body_profile: dict
    size_chart: SizeChartIn

    @field_validator("category")
    @classmethod
    def category_in_taxonomy(cls, value: str) -> str:
        if value not in occ.CATEGORIES:
            raise ValueError(f"category must be one of: {', '.join(occ.CATEGORIES)}")
        return value

    @field_validator("fit_type")
    @classmethod
    def fit_in_scale(cls, value: str) -> str:
        if value not in occ.FIT_SCALE:
            raise ValueError(f"fit_type must be one of: {', '.join(occ.FIT_SCALE)}")
        return value


@router.post("/size/recommend")
async def size_recommend(request: SizeRequest) -> dict:
    return size_service.recommend_size(
        category=request.category,
        fit_type=request.fit_type,
        body_profile=request.body_profile,
        rows=[row.regions() | {"label": row.label} for row in request.size_chart.rows],
        brand=request.size_chart.brand,
    )
