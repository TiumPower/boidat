import logging

from fastapi import FastAPI

from . import engine as face_engine
from .db import init_db
from .routes import faces, health

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")

app = FastAPI(
    title="BƠI ĐẠT — Face Service",
    description=(
        "Nhận diện khuôn mặt cho quầy điểm danh. Chạy độc lập với ứng dụng Rails, "
        "chỉ bind 127.0.0.1, mọi request ký HMAC-SHA256."
    ),
    version="1.0.0",
)

app.include_router(health.router)
app.include_router(faces.router)


@app.on_event("startup")
def on_startup() -> None:
    init_db()
    # Nạp mô hình ngay lúc khởi động: nếu để nạp lười, lượt quét đầu tiên của ca
    # trực mất 3–5 giây và lễ tân sẽ tưởng máy treo.
    face_engine.warmup()
