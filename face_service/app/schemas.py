from pydantic import BaseModel, Field


class EnrollRequest(BaseModel):
    workspace_id: int
    student_id: int
    # Danh sách ảnh base64. Nhiều ảnh cho cùng một em thì nhận diện ổn định hơn
    # hẳn — khuyến nghị 3 ảnh ở ba góc.
    images: list[str] = Field(min_length=1, max_length=8)


class EnrollResponse(BaseModel):
    face_id: str
    model: str
    quality: float
    samples: int
    skipped: int = 0


class SearchRequest(BaseModel):
    workspace_id: int
    image: str
    top_k: int = 3
    # Rails gửi ngưỡng của từng trung tâm (cấu hình được ở màn hình BOD).
    threshold: float | None = None


class Match(BaseModel):
    student_id: int
    score: float


class SearchResponse(BaseModel):
    matches: list[Match]
    liveness: dict
    threshold: float
    elapsed_ms: int


class DeleteRequest(BaseModel):
    workspace_id: int
