from fastapi import APIRouter
from sqlalchemy import text

from .. import engine as face_engine
from ..config import get_settings
from ..db import engine as db_engine

router = APIRouter()


@router.get("/healthz")
def healthz():
    """Kiểm tra cả mô hình lẫn database — healthcheck nửa vời sẽ báo 'ok' trong
    khi Postgres đã chết và mọi lượt quét đều lỗi."""
    settings = get_settings()
    status = {"status": "ok", "model": settings.model_name, "database": "ok", "faces": None}

    try:
        with db_engine.connect() as conn:
            status["faces"] = conn.execute(text("SELECT COUNT(*) FROM face_embeddings")).scalar()
    except Exception as exc:
        status["status"] = "degraded"
        status["database"] = str(exc)[:120]

    status["model_loaded"] = face_engine._app is not None
    return status
