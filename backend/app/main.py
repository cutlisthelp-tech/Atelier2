import time
from contextlib import asynccontextmanager

from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse

from app.config import APP_NAME, APP_VERSION, feature_flags
from app.errors import AtelierError, FailureState, error_envelope
from app.models.manager import RegistryEntryError, manager
from app.routers import analysis, recommend, search, size, tryon
from app.services import vton_service

_started_at = time.monotonic()

# Failure states caused by the input photo, not by the service itself.
INPUT_DERIVED = {
    FailureState.NO_PERSON,
    FailureState.MULTIPLE_PEOPLE,
    FailureState.POOR_IMAGE,
    FailureState.INSUFFICIENT_DATA,
    FailureState.NO_SIZE_CHART,
    FailureState.VTON_UNSUPPORTED_GARMENT,
}


@asynccontextmanager
async def lifespan(_: FastAPI):
    try:
        manager.discover()
    except RegistryEntryError:
        # /models reports the broken registry honestly; health stays up.
        pass
    yield


def create_app() -> FastAPI:
    app = FastAPI(title=APP_NAME, version=APP_VERSION, lifespan=lifespan)

    # The Android client is not subject to CORS; this only lets the local
    # web preview (a developer surface) reach a local backend.
    app.add_middleware(
        CORSMiddleware,
        allow_origin_regex=r"https?://(localhost|127\.0\.0\.1)(:\d+)?",
        allow_methods=["*"],
        allow_headers=["*"],
    )

    @app.exception_handler(AtelierError)
    async def atelier_error_handler(_: Request, exc: AtelierError) -> JSONResponse:
        status = 422 if exc.state in INPUT_DERIVED else 503
        return JSONResponse(status_code=status, content=error_envelope(exc.state, exc.message))

    app.include_router(analysis.router)
    app.include_router(recommend.router)
    app.include_router(tryon.router)
    app.include_router(size.router)
    app.include_router(search.router)

    @app.get("/health")
    async def health() -> dict:
        return {
            "status": "ok",
            "service": APP_NAME,
            "version": APP_VERSION,
            "uptime_seconds": round(time.monotonic() - _started_at, 3),
            "vton": {
                "provider": vton_service.PROVIDER_NAME,
                "configured": vton_service.configured(),
            },
        }

    @app.get("/config/feature-flags")
    async def get_feature_flags() -> dict:
        return {"feature_flags": feature_flags()}

    return app


app = create_app()
