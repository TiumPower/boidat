"""Lưu vector khuôn mặt trong Postgres + pgvector.

Vì sao pgvector chứ không phải FAISS: quy mô một trung tâm là vài nghìn khuôn
mặt, ở mức đó truy vấn cosine trên Postgres dưới 50ms — nhanh hơn nhiều so với
ngưỡng 3 giây của yêu cầu. Đổi lại ta được tính bền vững (không phải rebuild
index trong RAM sau mỗi lần restart), lọc theo workspace ngay trong câu truy vấn,
và backup chung với cơ chế backup Postgres đang có. Khi vượt ~50k vector thì mới
cần cân nhắc FAISS/HNSW.
"""

from contextlib import contextmanager

from sqlalchemy import create_engine, text
from sqlalchemy.orm import sessionmaker

from .config import get_settings

_settings = get_settings()
engine = create_engine(_settings.face_database_url, pool_pre_ping=True, future=True)
SessionLocal = sessionmaker(bind=engine, expire_on_commit=False, future=True)

SCHEMA = """
CREATE EXTENSION IF NOT EXISTS vector;

CREATE TABLE IF NOT EXISTS face_embeddings (
    id           BIGSERIAL PRIMARY KEY,
    workspace_id BIGINT      NOT NULL,
    student_id   BIGINT      NOT NULL,
    embedding    vector(512) NOT NULL,
    quality      REAL        NOT NULL DEFAULT 0,
    model        TEXT        NOT NULL,
    created_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Tra cứu luôn lọc theo workspace trước, nên index phải bắt đầu bằng cột đó.
CREATE INDEX IF NOT EXISTS idx_face_workspace ON face_embeddings (workspace_id);
CREATE INDEX IF NOT EXISTS idx_face_student   ON face_embeddings (workspace_id, student_id);

-- Nhật ký truy xuất dữ liệu sinh trắc học — Nghị định 13/2023 yêu cầu ghi log
-- mọi lần truy cập, không chỉ lần ghi.
CREATE TABLE IF NOT EXISTS access_logs (
    id           BIGSERIAL PRIMARY KEY,
    workspace_id BIGINT      NOT NULL,
    action       TEXT        NOT NULL,
    student_id   BIGINT,
    score        REAL,
    detail       TEXT,
    created_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_access_time ON access_logs (workspace_id, created_at DESC);
"""


def init_db() -> None:
    with engine.begin() as conn:
        for statement in SCHEMA.strip().split(";\n"):
            if statement.strip():
                conn.execute(text(statement))


@contextmanager
def session_scope():
    session = SessionLocal()
    try:
        yield session
        session.commit()
    except Exception:
        session.rollback()
        raise
    finally:
        session.close()


def log_access(session, workspace_id: int, action: str, student_id=None, score=None, detail=None) -> None:
    session.execute(
        text(
            "INSERT INTO access_logs (workspace_id, action, student_id, score, detail) "
            "VALUES (:w, :a, :s, :sc, :d)"
        ),
        {"w": workspace_id, "a": action, "s": student_id, "sc": score, "d": detail},
    )
