FROM python:3.11-slim

# InsightFace cần các thư viện đồ hoạ hệ thống mà bản slim không có sẵn.
RUN apt-get update && apt-get install -y --no-install-recommends \
      libgl1 libglib2.0-0 libgomp1 curl \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /srv

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Tải sẵn bộ mô hình vào image: nếu tải lúc khởi động, container đầu tiên sau
# mỗi lần deploy sẽ mất vài phút và quầy điểm danh đứng hình.
RUN python -c "from insightface.app import FaceAnalysis; \
    FaceAnalysis(name='buffalo_l', providers=['CPUExecutionProvider']).prepare(ctx_id=-1)"

COPY app ./app

ENV PYTHONUNBUFFERED=1
EXPOSE 8008

HEALTHCHECK --interval=30s --timeout=5s --start-period=40s \
  CMD curl -fsS http://127.0.0.1:8008/healthz || exit 1

# Một worker là đủ: mô hình chiếm ~700MB RAM, nhân thêm worker là nhân RAM.
# Quầy điểm danh quét tuần tự nên không cần song song.
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8008", "--workers", "1"]
