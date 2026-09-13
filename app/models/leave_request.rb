# Đơn xin nghỉ của giáo viên (FR-305 → FR-211).
class LeaveRequest < ApplicationRecord
  acts_as_tenant(:workspace)

  STATUSES = %w[pending approved rejected].freeze
  STATUS_LABELS = { "pending" => "Chờ duyệt", "approved" => "Đã duyệt", "rejected" => "Từ chối" }.freeze

  belongs_to :workspace
  belongs_to :teacher
  belongs_to :reviewed_by, class_name: "User", optional: true

  validates :status, inclusion: { in: STATUSES }

  scope :recent,  -> { order(created_at: :desc) }
  scope :pending, -> { where(status: "pending") }

  def pending?  = status == "pending"
  def approved? = status == "approved"
  def status_label = STATUS_LABELS[status]

  def lessons = Lesson.where(id: lesson_ids).order(:date, :start_hour)

  # Số học viên bị ảnh hưởng — con số admin cần thấy trước khi bấm duyệt.
  def affected_students
    Student.joins(enrollments: { swim_class: :lessons })
           .where(lessons: { id: lesson_ids })
           .where(enrollments: { status: "active" }).distinct
  end

  def label = "#{lesson_ids.size} buổi · #{I18n.l(created_at.to_date, format: '%d/%m')}"
end
