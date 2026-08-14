import time

from fastapi import FastAPI, Request
from fastapi.responses import JSONResponse

from app.config import APP_NAME, APP_VERSION, feature_flags
from app.errors import AtelierError, error_envelope

_started_at = time.monotonic()


def create_app() -> FastAPI:
    app = FastAPI(title=APP_NAME, version=APP_VERSION)

    @app.exception_handler(AtelierError)
    async def atelier_error_handler(_: Request, exc: AtelierError) -> JSONResponse:
        return JSONResponse(status_code=503, content=error_envelope(exc.state, exc.message))

    @app.get("/health")
    async def health() -> dict:
        return {
            "status": "ok",
            "service": APP_NAME,
            "version": APP_VERSION,
            "uptime_seconds": round(time.monotonic() - _started_at, 3),
        }

    @app.get("/config/feature-flags")
    async def get_feature_flags() -> dict:
        return {"feature_flags": feature_flags()}

    return app


app = create_app()
