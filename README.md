# BƠI ĐẠT — Hệ thống quản lý trung tâm dạy bơi

Nền tảng multi-workspace: mỗi trung tâm dạy bơi là một **Workspace**, bên trong
có nhiều **hồ bơi (Pool)**. Xây theo SRS v1.7 và bộ UX/UI 5 cổng vào của BƠI ĐẠT.

```
~/Desktop/boidat/
├── app/, config/, db/   Rails 7.2 · Ruby 3.2.2 · Postgres · Tailwind v4 · Hotwire · Sidekiq
└── face_service/        FastAPI + InsightFace (CPU) + pgvector — chạy độc lập
```

## Năm cổng vào

| Cổng | Đường dẫn | Ai dùng | Nội dung chính |
|---|---|---|---|
| Super Admin nền tảng | `/admin` | Bên bán sản phẩm | Quản lý trung tâm, gói thuê bao, doanh thu nền tảng |
| Cổng điều hành (S1) | `/merchant/bod` | BOD của trung tâm | Dashboard đa hồ, báo cáo, hồ bơi, nhân sự, giáo viên, cấu hình, nhật ký |
| Cổng vận hành (S2) | `/merchant/ops` | Admin · Sale | Bảng master data lịch, đăng ký học viên, đơn hàng, chấm công, chat |
| Quầy điểm danh (S3) | `/desk` | Lễ tân tại hồ | Quét khuôn mặt, vé lẻ, danh sách ca trực |
| Cổng giáo viên (S4) | `/teacher` | Giáo viên | Lịch dạy, giáo án, nhận xét, bảng công, đăng ký lịch, xin nghỉ |
| Cổng phụ huynh (S5) | `<subdomain>` hoặc `/w/:slug` | Phụ huynh · học viên | Hộ gia đình, tiến độ, nhận xét, hoá đơn, xin vắng, chat, ảnh khuôn mặt |

> Namespace controller của cổng giáo viên là **`Coach::`**, không phải `Teacher::` —
> model `Teacher` và module `Teacher::` va nhau dưới Zeitwerk. Route helper vẫn là
> `teacher_*`, đường dẫn vẫn là `/teacher`.

## Chạy dev

```bash
bin/setup                 # bundle + db:prepare
bin/rails db:seed         # dữ liệu demo đúng theo bộ UX
bin/dev                   # http://localhost:3011 (Rails + tailwind watch)
```

Tài khoản demo (mật khẩu `boidat1234`):

| Vai trò | Email |
|---|---|
| Super Admin nền tảng | `quocvietlee@gmail.com` (đăng nhập ở `/admin/login`) |
| BOD | `bod@boidat.vn` |
| Admin quản lý hồ | `hoang@boidat.vn` |
| Sale | `tram@boidat.vn` |
| Lễ tân | `ngan@boidat.vn` |
| Giáo viên | `minh@boidat.vn` |
| Giáo viên thuê hồ | `khoa@caheo.vn` |

Phụ huynh: mở `/w/boidat`, dán mã QR của hộ (in ở màn **Học viên & gia đình** trong
cổng vận hành). Học viên người lớn tự học đăng nhập bằng SĐT `0987654321` — mã OTP
hiện thẳng trên màn hình ở môi trường dev.

## Hai trục phân quyền

Đây là nền móng, không thể bổ sung sau:

1. **Workspace** — `acts_as_tenant`, row-level `workspace_id`, subdomain riêng.
2. **Pool (hồ bơi)** — mọi truy vấn nghiệp vụ lọc theo danh sách hồ người dùng
   được gán. BOD thấy tất cả các hồ; các vai trò khác chỉ thấy hồ được gán.

Cả ba cổng của nhân sự dùng chung concern `StaffScoped`. Controller nghiệp vụ đọc
dữ liệu qua `pool_scope(...)` thay vì gọi thẳng model, để không quên lọc theo hồ.

**Một ngoại lệ có chủ đích** (`FR-235`): tra cứu khuôn mặt chạy trên toàn bộ học
viên của workspace, không lọc theo hồ — quét ở quầy nào cũng ra. Việc chặn nằm ở
`StudentCheckInContext`: học viên hồ khác chỉ hiện tên, ảnh và tên cơ sở trực
thuộc, và không cho điểm danh.

## Quy tắc nghiệp vụ là cấu hình, không phải code

13/26 điểm `OQ` trong SRS đã chốt, 13 điểm còn lại vẫn có thể đổi sau khi vận
hành thật. Vì vậy mọi quy tắc còn tranh luận đều nằm trong
`Workspace#settings["business"]` (concern `BusinessSettings`), sửa được ở màn
hình **Cấu hình hệ thống** của BOD:

| Điểm | Mặc định đang chạy |
|---|---|
| `OQ-05` công lớp 1:4 | 2.0 công (tuyến tính) — đổi thành 1.5 nếu khách muốn đặt trần |
| `OQ-06` học viên vắng | Tính công theo **sĩ số đăng ký** — trung tâm chịu phần thiệt |
| `OQ-22` nhận xét | **Không** chặn lương, chỉ có deadline 24h và job nhắc |
| `OQ-25` 11 hay 12 buổi | Khoá 12 buổi = 11 buổi học + buổi 12 là buổi thi; buổi thi không trừ gói nhưng vẫn tính công |
| `OQ-07` danh sách thi | Cờ "đủ điều kiện" là cờ **dính** — học sang buổi sau vẫn không rớt khỏi danh sách |
| `OQ-13` vé lẻ | Mã QR một lần, không đăng ký khuôn mặt |
| `OQ-26` doanh thu thuê hồ | Tách thành dòng riêng trên dashboard |
| `OQ-03` quyền trong hộ | Chỉ chủ hộ xem được thanh toán; người đưa đón thì không |

Đổi bất kỳ giá trị nào ở trên là đổi hành vi hệ thống — không cần sửa code, không
cần deploy lại.

## Dịch vụ nhận diện khuôn mặt

Xem [`face_service/README.md`](face_service/README.md). Tóm tắt: InsightFace
`buffalo_l` chạy CPU, vector lưu trong Postgres + pgvector, mọi request ký
HMAC-SHA256, chỉ bind `127.0.0.1`.

Nguyên tắc vận hành: **service chết không được làm chết quầy điểm danh.**
`FaceClient` nuốt mọi lỗi và trả kết quả rỗng; PWA quầy tự rơi xuống tra cứu theo
tên, hoặc admin điểm danh tay trên bảng master data (`FR-234`).

## Test

```bash
bin/rails test                                   # 139 test Ruby
cd face_service && .venv/bin/python -m pytest -q # 10 test Python
```

Lưới an toàn tập trung vào những chỗ hỏng là mất tiền hoặc mất niềm tin:
rò rỉ dữ liệu giữa các hồ, trừ buổi, chấm công, idempotency thanh toán, ngoại lệ
tra cứu khuôn mặt, và vòng đời khoá học.

## Deploy

`bundle exec cap production deploy` (Capistrano + rbenv). Trên máy chủ cần:

- Postgres (`boidat_production`) + Redis
- `shared/.env` — xem bảng biến môi trường bên dưới
- systemd: `config/systemd/*.service` (puma user unit, sidekiq system unit, face service)
- nginx: `config/nginx/boidat.czin.net.conf` — **phải có block `/cable`**, thiếu
  nó thì WebSocket bị từ chối âm thầm và chat chỉ cập nhật sau khi F5
- Cert wildcard `*.boidat.czin.net` qua DNS-01 (mỗi trung tâm một subdomain)

### Biến môi trường

```
PLATFORM_HOST BOIDAT_DATABASE_PASSWORD SECRET_KEY_BASE REDIS_URL
PAYOS_CLIENT_ID PAYOS_API_KEY PAYOS_CHECKSUM_KEY
VAPID_PUBLIC_KEY VAPID_PRIVATE_KEY VAPID_SUBJECT
BREVO_API_KEY MAIL_FROM MAIL_FROM_NAME
FACE_SERVICE_URL FACE_SERVICE_SECRET FACE_DB_PASSWORD
SENTRY_DSN SHOW_OTP
```

Mã đơn PayOS dùng tiền tố **73** để tách khỏi các app khác dùng chung tài khoản
merchant (loyalty 71, estate 72). Trong nội bộ app còn chia hai dải: `73_0xx` cho
hoá đơn thuê bao nền tảng, `73_1xx` cho đơn khoá học của trung tâm — webhook tra
Order trước nên hai dải không được chồng nhau.

## Job định kỳ

| Job | Lịch | Việc |
|---|---|---|
| `CourseMaintenanceJob` | 08:00 hằng ngày | Đóng khoá hết hạn, nhắc sắp hết hạn, nhắc còn ít buổi |
| `LessonReminderJob` | mỗi giờ | Nhắc buổi học trước 2 tiếng |
| `FeedbackReminderJob` | 19:00 hằng ngày | Nhắc giáo viên nộp nhận xét quá hạn |
| `BillingRenewalJob` | 10:30 hằng ngày | Hoá đơn thuê bao nền tảng + tạm ngưng trung tâm quá hạn |

## Còn lại cần khách quyết

Ba điểm đang chạy theo mặc định ở trên nhưng nên xác nhận sớm, vì đổi thì phải
chạy lại số liệu đã tính: `OQ-05` (công lớp 1:4), `OQ-06` (cơ sở tính công khi có
học viên vắng), `OQ-25` (buổi 12 có phải buổi thi không).

Hai phụ thuộc bên ngoài: tài khoản **merchant PayOS** đã kích hoạt, và **VPS**
cho `boidat.czin.net` + wildcard DNS.
