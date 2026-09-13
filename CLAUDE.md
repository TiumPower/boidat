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
