# Đăng ký học của một học viên vào một lớp, kèm số buổi còn lại và hạn dùng.
class Enrollment < ApplicationRecord
  acts_as_tenant(:workspace)

  STATUSES = %w[active finished expired cancelled].freeze
  EXAM_RESULTS = %w[passed failed retake].freeze
  EXAM_LABELS = { "passed" => "Đạt", "failed" => "Chưa đạt", "retake" => "Thi lại" }.freeze

  belongs_to :workspace
  belongs_to :pool
  belongs_to :student
  belongs_to :swim_class
  belongs_to :package, optional: true
  has_many :attendances, dependent: :nullify
  has_one  :order, dependent: :nullify
  has_one  :contract, dependent: :destroy

  validates :status, inclusion: { in: STATUSES }
  validates :student_id, uniqueness: { scope: :swim_class_id }

  scope :active, -> { where(status: "active") }
  scope :expiring_within, ->(days) { active.where(expires_on: Date.current..(Date.current + days)) }

  before_validation :set_defaults, on: :create

  def active? = status == "active"
  def total_available = sessions_total + bonus_sessions
  def sessions_left = [total_available - sessions_used, 0].max
  def progress_label = "#{sessions_used}/#{total_available} buổi"
  def expired? = expires_on.present? && expires_on < Date.current
  def low_sessions? = sessions_left.positive? && sessions_left <= workspace.low_sessions_threshold

  # Trừ đúng một buổi khi điểm danh thành công (BR-05). Buổi thi có bị trừ hay
  # không là tham số cấu hình (OQ-25).
  def consume_session!(exam: false)
    return false if exam && !workspace.exam_deducts_session?
    return false unless active?
    with_lock do
      increment!(:sessions_used)
      refresh_status!
    end
    true
  end

  def restore_session!
    with_lock { decrement!(:sessions_used) if sessions_used.positive? }
  end

  # Vào danh sách thi khi số buổi đã học BẰNG ĐÚNG mốc cấu hình (FR-208).
  # Cờ exam_eligible_at là "dính": học sang buổi kế tiếp vẫn không rớt khỏi
  # danh sách cho tới khi có kết quả thi (OQ-07).
  def check_exam_eligibility!
    target = swim_class.course&.graduation_session || workspace.graduation_at_session
    return if exam_eligible_at.present?
    return unless sessions_used == target
    update!(exam_eligible_at: Time.current)
    student.update!(exam_eligible_at: Time.current) if workspace.exam_eligible_sticky?
  end

  def exam_eligible?
    return true if exam_eligible_at.present? && workspace.exam_eligible_sticky?
    target = swim_class.course&.graduation_session || workspace.graduation_at_session
    sessions_used == target
  end

  def exam_result_label = EXAM_RESULTS.include?(exam_result) ? EXAM_LABELS[exam_result] : nil

  def refresh_status!
    if sessions_used >= total_available
      update!(status: "finished")
    elsif expired?
      update!(status: "expired")
    end
  end

  private

  def set_defaults
    self.pool ||= swim_class&.pool
    self.starts_on ||= swim_class&.start_date || Date.current
    self.sessions_total = package&.session_count || swim_class&.total_sessions || 0 if sessions_total.to_i.zero?
    days = package&.expiry_days || workspace&.package_validity_days || 365
    self.expires_on ||= (starts_on || Date.current) + days.days
  end
end
