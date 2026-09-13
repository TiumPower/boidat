"""Bọc InsightFace: phát hiện khuôn mặt + sinh embedding 512 chiều.

Mô hình được nạp một lần lúc khởi động và warm-up bằng một ảnh giả — nếu để nạp
lười, lượt quét đầu tiên của ca trực sẽ mất 3–5 giây và lễ tân sẽ tưởng máy treo.
"""

import logging
import threading

import cv2
import numpy as np

from .config import get_settings

logger = logging.getLogger(__name__)

_lock = threading.Lock()
_app = None


def get_app():
    """Trả về FaceAnalysis đã nạp sẵn (singleton, thread-safe)."""
    global _app
    if _app is not None:
        return _app
    with _lock:
        if _app is None:
            from insightface.app import FaceAnalysis

            settings = get_settings()
            app = FaceAnalysis(
                name=settings.model_name,
                providers=["CPUExecutionProvider"],
                allowed_modules=["detection", "recognition"],
            )
            app.prepare(ctx_id=-1, det_size=(settings.det_size, settings.det_size))
            _app = app
            logger.info("InsightFace %s đã sẵn sàng (CPU)", settings.model_name)
    return _app


def warmup() -> None:
    """Chạy thử một lần để nạp trọng số vào bộ nhớ trước khi nhận request thật."""
    try:
        blank = np.zeros((320, 320, 3), dtype=np.uint8)
        get_app().get(blank)
    except Exception as exc:  # pragma: no cover - chỉ log, không chặn khởi động
        logger.warning("Warm-up thất bại: %s", exc)


def decode_image(raw: bytes):
    array = np.frombuffer(raw, dtype=np.uint8)
    image = cv2.imdecode(array, cv2.IMREAD_COLOR)
    if image is None:
        raise ValueError("Không đọc được ảnh")
    return image


def largest_face(image):
    """Khuôn mặt lớn nhất trong khung — ở quầy, đó là người đang đứng quét.

    Trả về None khi không thấy mặt nào hoặc mặt quá nhỏ: thà báo "không nhận ra"
    còn hơn nhận nhầm người đi ngang phía sau.
    """
    faces = get_app().get(image)
    if not faces:
        return None

    settings = get_settings()
    face = max(faces, key=lambda f: (f.bbox[2] - f.bbox[0]) * (f.bbox[3] - f.bbox[1]))
    width = face.bbox[2] - face.bbox[0]
    height = face.bbox[3] - face.bbox[1]
    if min(width, height) < settings.min_face_pixels:
        return None
    return face


def embed(image) -> tuple[np.ndarray | None, float, dict]:
    """Sinh embedding đã chuẩn hoá L2 + điểm chất lượng + thông tin khuôn mặt."""
    face = largest_face(image)
    if face is None:
        return None, 0.0, {}

    vector = np.asarray(face.normed_embedding, dtype=np.float32)
    width = float(face.bbox[2] - face.bbox[0])
    height = float(face.bbox[3] - face.bbox[1])
    info = {
        "bbox": [float(v) for v in face.bbox],
        "det_score": float(face.det_score),
        "face_pixels": min(width, height),
    }
    # Chất lượng gộp: độ tin cậy phát hiện × kích thước khuôn mặt so với khung.
    coverage = min(1.0, (width * height) / (image.shape[0] * image.shape[1]) * 6)
    quality = round(float(face.det_score) * (0.6 + 0.4 * coverage), 4)
    return vector, quality, info
