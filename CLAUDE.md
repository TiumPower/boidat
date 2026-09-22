# BƠI ĐẠT — ghi chú cho Claude Code

Đọc `README.md` trước. File này chỉ ghi những thứ dễ vấp mà đọc code không thấy ngay.

## Bẫy đã gặp

- **Namespace `Coach::` chứ không phải `Teacher::`** cho cổng giáo viên. Model
  `Teacher` và module `Teacher::` va nhau dưới Zeitwerk (đúng lỗi Loyalty gặp với
  `Member`). Route helper vẫn `teacher_*`, path vẫn `/teacher`.
- **Ghim `json ~> 2.21`.** json 3.x bỏ keyword `quirks_mode` mà ActiveRecord 7.2
  còn dùng khi ghi cột jsonb → mọi migration tạo bảng có jsonb đều nổ.
- **`member_root`** phải khai bằng `get ""` chứ không phải `root` — với `root`,
  Rails sinh URL thành `/?workspace_slug=x` thay vì `/w/x` ở chế độ đường dẫn.
- **`/w/:x` nhận cả slug lẫn subdomain.** Slug của "BƠI ĐẠT" là `boi-dat` nhưng
  subdomain là `boidat`; bắt người dùng nhớ hai chuỗi khác nhau chỉ tổ 404.
- **`pool_scope` không phải helper của view.** Nó là method của controller —
  gọi trong view sẽ nổ `NoMethodError`.
- Chạy `bin/rails tailwindcss:build` sau khi sửa CSS, hoặc dùng `bin/dev`.
  `rails server` trần KHÔNG biên dịch Tailwind.
- **Helper `member_*` phải truyền tham số bằng keyword** (`member_student_path(id:)`),
  không truyền vị trí. Segment `(/w/:workspace_slug)` là tuỳ chọn, nên ở chế độ
  subdomain nó nuốt mất đối số vị trí đầu tiên → sinh sai URL rồi nổ 500 ĐÚNG TRÊN
  PRODUCTION mà dev không tái hiện được. `customer_subdomain_test.rb` chạy ở chế độ
  subdomain chính là để bắt lỗi này.

- **Mã QR là của TỪNG người giám hộ**, không phải của hộ. Chủ hộ và người đưa
  đón có quyền khác nhau (OQ-03); dùng chung một mã thì không thể biết ai đang
  quét, và mọi phân quyền theo người trở thành vô nghĩa. Mã cấp hộ vẫn nhận để
  link cũ không chết, nhưng nó dẫn về chủ hộ.
- **Đo N+1 phải `clear_query_cache` trước mỗi lần đếm.** Query cache của Rails
  sống xuyên các request trong cùng một integration test, nên lần GET thứ hai
  ăn cache sạch và phép đo trả về 0 — bộ đo xanh rờn trong khi không đo gì cả.
- **Seed không được gán `external_ref` cho FaceProfile.** `registered?` chính là
  `external_ref.present?`, tức là lời khai "vector này có thật trong face
  service". Khai khống thì quầy quét mãi không ra mà không ai hiểu vì sao.
- **Controller Stimulus nạp kiểu eager toàn bộ.** Thêm file vào
  `app/javascript/controllers/` là nó tải trên MỌI trang của cả năm cổng, kể cả
  PWA chạy 4G. Đừng để lại controller không dùng.

- **Sửa locale phải nhìn cả hai file.** `config.i18n.fallbacks = [:en]`, nên xoá
  một khoá ở riêng `vi.yml` KHÔNG làm test đỏ — nó lặng lẽ rơi về tiếng Anh và
  người Việt thấy chuỗi tiếng Anh. Test chỉ đỏ khi khoá mất ở cả hai file.
- **`tld_length` suy từ `PLATFORM_HOST`, đừng viết cứng.** Host nền tảng ba nhãn
  (`boidat.tiumpower.com`) mà tld_length mặc định là 1 thì Rails đọc chính apex thành
  "subdomain boidat" — trùng subdomain của trung tâm BƠI ĐẠT. Dev và test chạy
  trên `example.com` hai nhãn nên đặt cứng số 2 là hỏng mọi test subdomain.

- **Đăng nhập phụ huynh nằm ở `/vao`, không phải `/login`.** Hai cổng chạy chung
  một host ở production. Segment `(/w/:workspace_slug)` tuỳ chọn nên `login` của
  phụ huynh rút gọn thành đúng `/login`, trùng route Devise của nhân sự khai
  phía trên và thua nó — phụ huynh rơi vào form email + mật khẩu họ không có.
  Trong test đừng viết cứng đường dẫn, dùng `member_login_path(workspace_slug:)`.
- **Luật `rack_attack` phải khớp đường dẫn THẬT của app này.** Bản bê từ app
  khác nhắm vào `/merchant/login` và `params["email"]` — cái thứ nhất không tồn
  tại, cái thứ hai là `phone` ở đây. Cả hai luật im lặng không khớp lần nào; một
  luật không khớp trông giống hệt một luật đang bảo vệ tốt.

## Quy ước phải giữ

- Mọi truy vấn nghiệp vụ đi qua `pool_scope(...)` hoặc lọc `pool_id` tường minh.
  Quên một chỗ là rò rỉ dữ liệu giữa các hồ.
- Mọi thao tác ghi gọi `audit!(...)` — nhật ký thao tác là yêu cầu hợp đồng (FR-221).
- Quy tắc nghiệp vụ còn tranh luận đọc từ `workspace.setting(...)`, không hard-code.
  Danh sách đầy đủ ở `app/models/concerns/business_settings.rb`.
- Quy tắc trừ buổi chỉ nằm ở `AttendanceRecorder`. Ba đường vào (khuôn mặt / vé QR /
  sửa tay) đều phải đi qua đó, không tự viết lại.
- Tiền: `Order` là đơn khoá học trung tâm thu của phụ huynh; `Invoice` là hoá đơn
  thuê bao nền tảng. Đừng lẫn hai cái.

## Chạy nhanh

```bash
bin/dev                                    # port 3011
bin/rails test                             # toàn bộ
bin/rails test test/integration/xxx_test.rb
cd face_service && .venv/bin/python -m pytest -q
```
