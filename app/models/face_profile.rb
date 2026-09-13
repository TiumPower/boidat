# Metadata hồ sơ khuôn mặt. Vector 512 chiều nằm ở face_service (FastAPI +
# InsightFace); Rails chỉ giữ ảnh gốc, chất lượng và thống kê quét để biết khi
# nào phải yêu cầu chụp lại — khuôn mặt trẻ em thay đổi nhanh theo tháng (OQ-01.3).
class FaceProfile < ApplicationRecord
  acts_as_tenant(:workspace)

  belongs_to :workspace
  belongs_to :student
  has_many_attached :photos

  scope :live, -> { where(deleted_at: nil) }
  scope :needs_recapture, -> { live.where(recapture_flag: true) }

  def registered? = deleted_at.nil? && external_ref.present?

  def fail_ratio
    return 0.0 if scan_count.to_i.zero?
    fail_count.to_f / scan_count
  end

  # Tỷ lệ quét lỗi vượt ngưỡng cấu hình → gắn cờ để quầy/PWA nhắc chụp lại ảnh.
  def refresh_recapture_flag!
    threshold = workspace.setting("face_recapture_fail_ratio").to_f
    should_flag = scan_count.to_i >= 4 && fail_ratio >= threshold
    update!(recapture_flag: should_flag) if recapture_flag != should_flag
  end

  def record_scan!(success:)
    increment!(:scan_count)
    increment!(:fail_count) unless success
    refresh_recapture_flag!
  end

  # Xoá dữ liệu sinh trắc theo yêu cầu của phụ huynh (NĐ 13/2023).
  def soft_delete!
    photos.purge_later
    update!(deleted_at: Time.current, external_ref: nil, recapture_flag: false)
  end
end
