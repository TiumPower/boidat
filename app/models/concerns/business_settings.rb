# Toàn bộ quy tắc nghiệp vụ "còn tranh luận" của SRS nằm ở đây dưới dạng tham số,
# đọc/ghi vào `workspaces.settings` (jsonb). Lý do: 13/26 điểm OQ đã chốt nhưng
# 13 điểm còn lại vẫn có thể đổi sau khi vận hành thật — nếu hard-code thì mỗi
# lần khách đổi ý là một lần sửa code và chạy lại số liệu.
#
# Default ở đây là phương án đội triển khai khuyến nghị, có ghi rõ nguồn.
module BusinessSettings
  extend ActiveSupport::Concern

  DEFAULTS = {
    # BR-02 + OQ-05 — công của giáo viên trong 1 tiết theo sĩ số.
    # Mức 4 học viên khách chưa chốt: mặc định suy tuyến tính (2.0).
    "credit_table" => { "1" => 0.5, "2" => 1.0, "3" => 1.5, "4" => 2.0 },

    # OQ-06 — tính công theo sĩ số ĐĂNG KÝ hay sĩ số CÓ MẶT.
    # Mặc định "registered": giáo viên không bị phạt vì phụ huynh vắng.
    "credit_basis" => "registered", # registered | present

    # OQ-22 — nhận xét của giáo viên KHÔNG chặn chấm công, chỉ có deadline.
    "feedback_blocks_payroll" => false,
    "feedback_deadline_hours" => 24,

    # BR-11 / FR-212b / OQ-25 — một khoá 12 buổi: 11 buổi học + buổi 12 là buổi thi.
    "course_sessions"        => 12,
    "graduation_at_session"  => 11,   # FR-208: đủ ĐÚNG 11 buổi thì vào danh sách thi
    "exam_session_index"     => 12,
    "exam_deducts_session"   => false, # buổi thi không trừ khỏi gói
    "exam_pays_credit"       => true,  # nhưng giáo viên vẫn được tính công
    "exam_eligible_sticky"   => true,  # OQ-07: đã vào danh sách thì không rớt ra

    # BR-11 — hạn dùng gói.
    "package_validity_days"  => 365,
    "expiry_warning_days"    => 30,

    # BR-12 / OQ-10 — vắng không báo thì KHÔNG trừ buổi.
    "no_show_deducts" => false,

    # OQ-13 — vé lẻ dùng mã QR một lần, không đăng ký dữ liệu sinh trắc học.
    "day_pass_uses_face" => false,

    # OQ-26 — doanh thu cho thuê hồ tách thành dòng riêng trên dashboard BOD.
    "rental_revenue_separate" => true,

    # OQ-03 — chỉ chủ hộ xem được lịch sử thanh toán; người đưa đón thì không.
    "household_scope_payments" => "owner_only", # owner_only | everyone

    # OQ-02 — phiên đăng nhập bằng QR không hết hạn; thu hồi bằng nút cấp lại QR.
    "qr_session_days" => nil,

    # FR-304 — hạn chót giáo viên gửi lịch đăng ký dạy cho tháng sau.
    "availability_deadline_day" => 25,

    # OQ-01 — ngưỡng nhận diện khuôn mặt (cosine, InsightFace buffalo_l).
    "face_match_threshold"  => 0.42,
    "face_review_threshold" => 0.35,
    "face_recapture_fail_ratio" => 0.25, # quét lỗi > 25% số buổi gần nhất → yêu cầu chụp lại
    "face_recent_window"    => 12,

    # BR-01 — một tiết = 60 phút.
    "lesson_minutes" => 60,

    # OQ-17 — nhắc gia hạn khi học viên còn ≤ n buổi.
    "low_sessions_threshold" => 2
  }.freeze

  # Đọc một tham số nghiệp vụ (đã ép kiểu theo default).
  def setting(key)
    key = key.to_s
    stored = settings.is_a?(Hash) ? settings.dig("business", key) : nil
    return DEFAULTS[key] if stored.nil?
    stored
  end

  def set_setting!(key, value)
    biz = (settings["business"] || {}).merge(key.to_s => value)
    update!(settings: settings.merge("business" => biz))
  end

  def update_business_settings!(attrs)
    biz = (settings["business"] || {}).merge(attrs.stringify_keys)
    update!(settings: settings.merge("business" => biz))
  end

  def business_settings = DEFAULTS.merge(settings["business"] || {})

  # -- Truy cập có ngữ nghĩa (dùng ở service/model, không rải `setting("…")`) --

  # Công của giáo viên cho một tiết với `headcount` học viên.
  # Vượt bảng cấu hình thì lấy mức cao nhất đã khai báo (đặt trần).
  def credits_for(headcount)
    table = setting("credit_table").transform_keys(&:to_s).transform_values(&:to_f)
    return 0.0 if headcount.to_i <= 0
    table[headcount.to_i.to_s] || table.max_by { |k, _| k.to_i }&.last.to_f
  end

  def credit_basis_registered? = setting("credit_basis").to_s == "registered"
  def course_session_count     = setting("course_sessions").to_i
  def graduation_at_session    = setting("graduation_at_session").to_i
  def exam_session_index       = setting("exam_session_index").to_i
  def exam_deducts_session?    = !!setting("exam_deducts_session")
  def exam_pays_credit?        = !!setting("exam_pays_credit")
  def exam_eligible_sticky?    = !!setting("exam_eligible_sticky")
  def package_validity_days    = setting("package_validity_days").to_i
  def no_show_deducts?         = !!setting("no_show_deducts")
  def day_pass_uses_face?      = !!setting("day_pass_uses_face")
  def rental_revenue_separate? = !!setting("rental_revenue_separate")
  def payments_owner_only?     = setting("household_scope_payments").to_s == "owner_only"
  def feedback_blocks_payroll? = !!setting("feedback_blocks_payroll")
  def lesson_minutes           = setting("lesson_minutes").to_i
  def low_sessions_threshold   = setting("low_sessions_threshold").to_i
  def face_match_threshold     = setting("face_match_threshold").to_f
  def face_review_threshold    = setting("face_review_threshold").to_f
  def availability_deadline_day = setting("availability_deadline_day").to_i
end
