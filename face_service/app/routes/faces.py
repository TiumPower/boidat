import base64
import binascii
import logging
import time

import numpy as np
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import text

from .. import engine as face_engine
from .. import liveness
from ..config import get_settings
from ..db import log_access, session_scope
from ..schemas import (
    DeleteRequest,
    EnrollRequest,
    EnrollResponse,
    Match,
    SearchRequest,
    SearchResponse,
)
from ..security import verify_signature

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/v1", dependencies=[Depends(verify_signature)])


def _decode(payload: str):
    settings = get_settings()
    try:
        raw = base64.b64decode(payload, validate=True)
    except (binascii.Error, ValueError) as exc:
        raise HTTPException(status_code=400, detail="Ảnh base64 không hợp lệ") from exc
    if len(raw) > settings.max_image_bytes:
        raise HTTPException(status_code=413, detail="Ảnh quá lớn")
    try:
        return face_engine.decode_image(raw)
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc


@router.post("/faces/enroll", response_model=EnrollResponse)
def enroll(payload: EnrollRequest):
    """Đăng ký / cập nhật khuôn mặt của một học viên.

    Ghi đè toàn bộ vector cũ của em đó: khuôn mặt trẻ em thay đổi nhanh theo
    tháng, giữ lại ảnh cũ chỉ làm loãng kết quả tra cứu (OQ-01).
    """
    settings = get_settings()
    vectors: list[tuple[np.ndarray, float]] = []
    skipped = 0

    for encoded in payload.images:
        image = _decode(encoded)
        vector, quality, _info = face_engine.embed(image)
        if vector is None:
            skipped += 1
            continue
        vectors.append((vector, quality))

    if not vectors:
        raise HTTPException(status_code=422, detail="Không tìm thấy khuôn mặt rõ trong ảnh gửi lên")

    with session_scope() as session:
        session.execute(
            text("DELETE FROM face_embeddings WHERE workspace_id = :w AND student_id = :s"),
            {"w": payload.workspace_id, "s": payload.student_id},
        )
        for vector, quality in vectors:
            session.execute(
                text(
                    "INSERT INTO face_embeddings (workspace_id, student_id, embedding, quality, model) "
                    "VALUES (:w, :s, :e, :q, :m)"
                ),
                {
                    "w": payload.workspace_id,
                    "s": payload.student_id,
                    "e": "[" + ",".join(f"{v:.6f}" for v in vector) + "]",
                    "q": quality,
                    "m": settings.model_name,
                },
            )
        log_access(
            session, payload.workspace_id, "enroll",
            student_id=payload.student_id, detail=f"{len(vectors)} ảnh, bỏ qua {skipped}",
        )

    best_quality = round(max(q for _v, q in vectors), 4)
    return EnrollResponse(
        face_id=f"{payload.workspace_id}:{payload.student_id}",
        model=settings.model_name,
        quality=best_quality,
        samples=len(vectors),
        skipped=skipped,
    )


@router.post("/faces/search", response_model=SearchResponse)
def search(payload: SearchRequest):
    """Tra cứu một ảnh trong phạm vi một workspace.

    NGOẠI LỆ CÓ CHỦ ĐÍCH (FR-235): chỉ lọc theo workspace, KHÔNG lọc theo hồ —
    quét ở quầy nào cũng phải tra ra học viên của cả ba cơ sở. Việc chặn điểm
    danh khi sai hồ nằm ở phía Rails, sau bước nhận diện này.
    """
    started = time.monotonic()
    settings = get_settings()
    threshold = payload.threshold or settings.match_threshold

    image = _decode(payload.image)
    live = liveness.check(image)

    vector, _quality, _info = face_engine.embed(image)
    if vector is None:
        return SearchResponse(matches=[], liveness=live, threshold=threshold,
                              elapsed_ms=int((time.monotonic() - started) * 1000))

    literal = "[" + ",".join(f"{v:.6f}" for v in vector) + "]"
    with session_scope() as session:
        # `<=>` là khoảng cách cosine của pgvector → điểm khớp = 1 − khoảng cách.
        rows = session.execute(
            text(
                "SELECT student_id, 1 - (embedding <=> CAST(:vec AS vector)) AS score "
                "FROM face_embeddings WHERE workspace_id = :w "
                "ORDER BY embedding <=> CAST(:vec AS vector) LIMIT :k"
            ),
            {"vec": literal, "w": payload.workspace_id, "k": max(payload.top_k * 3, 5)},
        ).all()

        # Một học viên có nhiều ảnh nên có nhiều vector — giữ điểm cao nhất của mỗi em.
        best: dict[int, float] = {}
        for student_id, score in rows:
            if score > best.get(student_id, -1):
                best[student_id] = float(score)

        matches = [
            Match(student_id=sid, score=round(score, 4))
            for sid, score in sorted(best.items(), key=lambda kv: -kv[1])
            if score >= settings.review_threshold
        ][: payload.top_k]

        top = matches[0] if matches else None
        log_access(
            session, payload.workspace_id, "search",
            student_id=top.student_id if top else None,
            score=top.score if top else None,
            detail=f"liveness={live['passed']}",
        )

    return SearchResponse(
        matches=matches, liveness=live, threshold=threshold,
        elapsed_ms=int((time.monotonic() - started) * 1000),
    )


@router.delete("/faces/{student_id}")
def delete_face(student_id: int, payload: DeleteRequest):
    """Xoá vĩnh viễn dữ liệu sinh trắc học của một học viên.

    Quyền yêu cầu xoá là bắt buộc theo Nghị định 13/2023/NĐ-CP, nên đây là xoá
    thật khỏi bảng vector chứ không phải đánh dấu.
    """
    with session_scope() as session:
        result = session.execute(
            text("DELETE FROM face_embeddings WHERE workspace_id = :w AND student_id = :s"),
            {"w": payload.workspace_id, "s": student_id},
        )
        log_access(session, payload.workspace_id, "delete", student_id=student_id,
                   detail=f"{result.rowcount} vector")
    return {"deleted": result.rowcount}
