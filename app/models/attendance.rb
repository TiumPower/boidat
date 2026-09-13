# Điểm danh: một dòng cho mỗi học viên trong mỗi buổi.
class Attendance < ApplicationRecord
  acts_as_tenant(:workspace)

  STATUSES = %w[present absent rejected].freeze
  METHODS  = %w[face qr manual].freeze
  METHOD_LABELS = { "face" => "Quét khuôn mặt", "qr" => "Vé QR", "manual" => "Sửa tay" }.freeze

  belongs_to :workspace
  belongs_to :pool
  belongs_to :lesson
  belongs_to :student
  belongs_to :enrollment, optional: true
  belongs_to :actor, class_name: "User", optional: true

  validates :status, inclusion: { in: STATUSES }
  validates :method, inclusion: { in: METHODS }
  validates :student_id, uniqueness: { scope: :lesson_id }

  scope :present, -> { where(status: "present") }
  scope :today,   -> { where(checked_in_at: Time.current.all_day) }

  before_validation { self.checked_in_at ||= Time.current }

  def present? = status == "present"
  def method_label = METHOD_LABELS[method]
end
