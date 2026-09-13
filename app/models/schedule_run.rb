# Một lần chạy bộ xếp lịch tự động (FR-205). Kết quả LUÔN dừng ở bản nháp —
# admin xem trước, chỉnh tay, rồi mới bấm Áp dụng.
class ScheduleRun < ApplicationRecord
  acts_as_tenant(:workspace)

  STATUSES = %w[draft applied discarded].freeze

  belongs_to :workspace
  belongs_to :pool
  belongs_to :created_by, class_name: "User", optional: true
  belongs_to :applied_by, class_name: "User", optional: true

  validates :status, inclusion: { in: STATUSES }

  scope :recent, -> { order(month: :desc, created_at: :desc) }
  scope :drafts, -> { where(status: "draft") }

  def draft?   = status == "draft"
  def applied? = status == "applied"

  def month_label = I18n.l(month, format: "%m/%Y")

  def proposal_rows = Array(proposals).map { |row| row.symbolize_keys }

  def status_label
    { "draft" => "Có bản nháp", "applied" => "Đã áp dụng", "discarded" => "Đã bỏ" }[status]
  end

  # Áp dụng bản nháp: đánh dấu các khung đã duyệt là "đã lên lịch" bằng cách để
  # chúng hiện như slot trống ĐÃ ĐƯỢC CHỐT trên bảng master data.
  #
  # Cố tình KHÔNG tự tạo lớp: lớp chỉ sinh ra khi có học viên thật đăng ký
  # (FR-204). Bộ xếp lịch chỉ quyết định "khung nào của thầy nào được mở bán".
  def apply!(by:, keep: nil)
    kept = keep.nil? ? proposal_rows : proposal_rows.select { |r| keep.include?(slot_key(r)) }
    transaction do
      update!(status: "applied", applied_by: by, applied_at: Time.current, proposals: kept.map(&:stringify_keys))
    end
    kept.size
  end

  def discard!(by:) = update!(status: "discarded", applied_by: by, applied_at: Time.current)

  def slot_key(row) = "#{row[:teacher_id]}:#{row[:weekday]}:#{row[:hour]}"
end
