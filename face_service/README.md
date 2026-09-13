# BƠI ĐẠT — Face Service

Service nhận diện khuôn mặt cho quầy điểm danh. Chạy **độc lập** với ứng dụng
Rails: khác ngôn ngữ, khác vòng đời deploy, khác hồ sơ tài nguyên (mô hình chiếm
~700MB RAM và ăn CPU theo đợt). Rails gọi sang qua HTTP nội bộ.

## Vì sao tự host thay vì dùng vendor

SRS để mở lựa chọn vendor (AWS Rekognition / Face++ / FPT.AI) hoặc self-host
(`OQ-01` mục 6). Chọn self-host InsightFace vì:

- **Dữ liệu sinh trắc học của trẻ em không rời khỏi máy chủ của trung tâm.**
  Với Nghị định 13/2023/NĐ-CP thì đây là điểm quyết định, không phải chi phí.
- Chi phí vận hành cố định (một container CPU) thay vì trả theo lượt gọi.
- Không phụ thuộc mạng ra Internet — hồ bơi hay mất mạng, mà điểm danh thì không
  được dừng.

## Kiến trúc

```
PWA quầy  ──ảnh──▶  Rails  ──HMAC──▶  face_service  ──▶  Postgres + pgvector
                      │                    │
                      │                    └─ InsightFace buffalo_l (ONNX, CPU)
                      └─ chặn theo hồ, trừ buổi, ghi nhật ký
```

- **Mô hình**: `buffalo_l` = SCRFD-10G (phát hiện) + w600k_r50 (embedding 512 chiều).
- **Chỉ mục**: Postgres + `pgvector`, khoảng cách cosine, lọc theo `workspace_id`.
  Vài nghìn khuôn mặt truy vấn dưới 50ms. Vượt ~50k vector mới cần cân nhắc FAISS/HNSW.
- **Hiệu năng thực tế** (VPS 4 vCPU, không GPU): phát hiện + embedding ~200–400ms
  cho ảnh 480×480. Yêu cầu của SRS là dưới 3 giây trên mạng 4G — còn dư nhiều.

## Ranh giới trách nhiệm

Service này **chỉ trả lời "ảnh này giống ai nhất"**. Nó không biết học viên
thuộc hồ nào, còn bao nhiêu buổi, hay hôm nay có lịch không. Toàn bộ quyết định
nghiệp vụ nằm ở Rails (`StudentCheckInContext`):

- Tra cứu chạy trên **toàn bộ học viên của workspace**, không lọc theo hồ — quét
  ở quầy nào cũng ra (`FR-235`).
- Rails mới là nơi chặn khi học viên thuộc hồ khác, hết buổi, hết hạn gói, hoặc
  hôm nay không có lịch.

Tách như vậy để một thay đổi chính sách (ví dụ cho phép học bù xuyên cơ sở)
không phải đụng tới service nhận diện.

## Chạy dev

```bash
cp .env.example .env          # đặt FACE_SERVICE_SECRET giống hệt bên Rails
docker compose up -d face-db  # Postgres + pgvector
python -m venv .venv && .venv/bin/pip install -r requirements.txt
.venv/bin/uvicorn app.main:app --reload --port 8008
```

Lần chạy đầu tiên InsightFace tải bộ mô hình (~280MB) về `~/.insightface`.
Trong Docker, bước tải nằm sẵn trong image để container khởi động là dùng được ngay.

## Chạy production

```bash
docker compose up -d --build
```

Cả hai container chỉ bind `127.0.0.1` — service **không bao giờ** được lộ ra
Internet. Rails gọi qua `FACE_SERVICE_URL=http://127.0.0.1:8008`.

## API

Mọi endpoint dưới `/v1` yêu cầu hai header:

| Header | Nội dung |
|---|---|
| `X-Timestamp` | Unix epoch giây |
| `X-Signature` | `HMAC-SHA256(secret, "<timestamp>.<body>")` dạng hex |

Chữ ký lệch quá 60 giây bị từ chối (chống replay).

| Endpoint | Việc |
|---|---|
| `GET /healthz` | Trạng thái mô hình + database + số vector đang lưu |
| `POST /v1/faces/enroll` | Đăng ký/cập nhật khuôn mặt. Ghi đè toàn bộ vector cũ của học viên đó |
| `POST /v1/faces/search` | Tra cứu, trả top-k kèm điểm khớp và kết quả liveness |
| `DELETE /v1/faces/{student_id}` | Xoá vĩnh viễn (quyền yêu cầu xoá theo NĐ 13/2023) |

## Ngưỡng khớp

| Điểm cosine | Xử lý |
|---|---|
| ≥ 0.42 | Khớp — màn hình xác nhận hiện ngay |
| 0.35 – 0.42 | Vùng xám — bắt lễ tân xác nhận bằng mắt trước khi trừ buổi |
| < 0.35 | Không nhận — chuyển sang tra cứu theo tên |

Ngưỡng cấu hình được cho từng trung tâm ở màn hình BOD; Rails gửi kèm theo mỗi
request. Nên hiệu chỉnh lại sau 2–4 tuần chạy thật, dựa trên bảng `access_logs`.

## Liveness — nói rõ giới hạn

Hiện tại là **liveness thụ động**: kiểm tra độ nét (phương sai Laplacian) và vân
moiré. Chặn được kiểu tấn công phổ biến nhất ở quầy — giơ điện thoại có sẵn ảnh.
**Không** chống được mặt nạ 3D hay màn hình chất lượng cao.

Muốn mạnh hơn thì làm active challenge (nháy mắt / quay đầu): PWA gửi 3 khung
hình liên tiếp, service so độ lệch — hàm `liveness.challenge_passed` đã sẵn sàng
cho việc đó, chỉ cần PWA gửi nhiều khung.

## Chất lượng xuống cấp theo thời gian

Khuôn mặt trẻ em thay đổi nhanh theo tháng. Học viên học nhiều khoá liên tiếp sẽ
dần bị nhận diện sai. Cơ chế đối phó nằm ở Rails: đếm tỷ lệ quét lỗi của từng
em (`FaceProfile#record_scan!`), vượt ngưỡng thì gắn cờ và nhắc phụ huynh chụp
lại ảnh trên PWA. Không có vòng lặp này thì sau 6–12 tháng tỷ lệ nhận diện tự
xuống cấp mà không ai biết.

## Nhật ký truy xuất

Bảng `access_logs` ghi mọi lần enroll / search / delete kèm điểm khớp. Nghị định
13/2023 yêu cầu ghi log **mọi lần truy cập** dữ liệu sinh trắc học, không chỉ
lần ghi. Đây cũng là nguồn dữ liệu để hiệu chỉnh ngưỡng.

## Test

```bash
.venv/bin/python -m pytest -q
```
