from functools import lru_cache

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    """Cấu hình service. Mọi giá trị đọc từ biến môi trường (file .env khi dev)."""

    # Bí mật dùng chung với Rails để ký HMAC mọi request.
    face_service_secret: str = "dev-face-secret"
    # Cho phép lệch đồng hồ bao nhiêu giây — chống replay.
    signature_max_skew: int = 60

    database_url: str = "postgresql+psycopg://localhost/boidat_face"

    # Ngưỡng khớp mặc định. Rails cũng có ngưỡng riêng trong cấu hình trung tâm
    # và gửi kèm theo request; giá trị ở đây chỉ là mức sàn của service.
    match_threshold: float = 0.42
    review_threshold: float = 0.35

    # buffalo_l là bộ mô hình cân bằng nhất cho CPU: SCRFD-10G phát hiện +
    # w600k_r50 sinh embedding 512 chiều.
    model_name: str = "buffalo_l"
    det_size: int = 640
    # Ảnh nhỏ hơn mức này gần như chắc chắn nhận diện sai — chặn sớm còn hơn
    # trả về một kết quả mà lễ tân tưởng là đúng.
    min_face_pixels: int = 60

    # Liveness thụ động: chặn ảnh in / ảnh chụp màn hình ở mức cơ bản.
    liveness_enabled: bool = True
    min_blur_score: float = 45.0

    max_image_bytes: int = 6 * 1024 * 1024

    model_config = SettingsConfigDict(env_file=".env", extra="ignore")


@lru_cache
def get_settings() -> Settings:
    return Settings()
