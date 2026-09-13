# Nhận xét của giáo viên cho từng học viên sau mỗi buổi (FR-303).
# Phụ huynh xem được (FR-406) — đây là đòn bẩy chăm sóc khách hàng mạnh nhất mà
# list gốc của khách chưa khai thác.
class SessionFeedback < ApplicationRecord
  acts_as_tenant(:workspace)

  TAGS = %w[progress needs_work afraid].freeze
  TAG_LABELS = { "progress" => "Tiến bộ tốt", "needs_work" => "Cần luyện thêm", "afraid" => "Sợ nước" }.freeze

  belongs_to :workspace
  belongs_to :pool
  belongs_to :lesson
  belongs_to :student
  belongs_to :teacher

  validates :student_id, uniqueness: { scope: :lesson_id }

  scope :recent, -> { order(created_at: :desc) }
  scope :sent,   -> { where.not(sent_at: nil) }

  def tag_label = TAG_LABELS[tag]
  def sent? = sent_at.present?
end
