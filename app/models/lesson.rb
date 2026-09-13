# Một buổi học cụ thể — một tiết 60 phút (BR-01). Đây là hạt nhân mà bảng master
# data, điểm danh và chấm công đều bám vào.
class Lesson < ApplicationRecord
  acts_as_tenant(:workspace)

  STATUSES = %w[scheduled done cancelled].freeze

  belongs_to :workspace
  belongs_to :pool
  belongs_to :teacher
  belongs_to :swim_class
  has_many :attendances, dependent: :destroy

  validates :status, inclusion: { in: STATUSES }
  validates :start_hour, inclusion: { in: 0..23 }

  scope :on,        ->(date) { where(date: date) }
  scope :between,   ->(from, to) { where(date: from..to) }
  scope :scheduled, -> { where(status: "scheduled") }
  scope :done,      -> { where(status: "done") }
  scope :upcoming,  -> { where("date >= ?", Date.current).order(:date, :start_hour) }

  def scheduled? = status == "scheduled"
  def done?      = status == "done"
  def cancelled? = status == "cancelled"

  def starts_at = Time.zone.local(date.year, date.month, date.day, start_hour)
  def time_label = format("%02d:00", start_hour)
  def past? = starts_at < Time.current

  # Nội dung buổi dạy: bản giáo viên sửa cho riêng buổi này thắng giáo án gốc.
  def content
    content_override.presence || course_session&.content
  end

  def title
    course_session&.title || (exam? ? "Thi tốt nghiệp" : "Buổi #{session_index}")
  end

  def course_session
    return nil unless swim_class.course && session_index
    @course_session ||= swim_class.course.plan_for(session_index)
  end

  def roster = swim_class.active_enrollments.map(&:student)

  def present_students
    attendances.select { |a| a.status == "present" }.map(&:student)
  end

  def label = "#{time_label} · 1:#{swim_class.class_type} · Buổi #{session_index}/#{swim_class.total_sessions}"
end
