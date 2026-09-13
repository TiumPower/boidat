# Đổi buổi / học bù (FR-211 bước 4–5, FR-404).
#
# Chính sách đã chốt (BR-12): nghỉ không báo thì KHÔNG bị trừ buổi, nhưng muốn
# đổi lịch thì phải đi qua đây chứ không phải cứ nghỉ là xong.
class MakeupRequest < ApplicationRecord
  acts_as_tenant(:workspace)

  ORIGINS = %w[teacher_leave guardian_absence].freeze
  CHOICES = %w[follow_teacher other_slot other_teacher].freeze
  CHOICE_LABELS = {
    "follow_teacher" => "Nghỉ theo thầy",
    "other_slot"     => "Khung giờ khác của thầy",
    "other_teacher"  => "Giữ khung giờ, đổi giáo viên"
  }.freeze
  STATUSES = %w[pending booked cancelled].freeze

  belongs_to :workspace
  belongs_to :pool
  belongs_to :enrollment
  belongs_to :student
  belongs_to :from_lesson, class_name: "Lesson", optional: true
  belongs_to :to_lesson,   class_name: "Lesson", optional: true
  belongs_to :leave_request, optional: true
  belongs_to :decided_by, class_name: "Guardian", optional: true

  validates :origin, inclusion: { in: ORIGINS }
  validates :status, inclusion: { in: STATUSES }
  validates :choice, inclusion: { in: CHOICES }, allow_nil: true

  scope :pending, -> { where(status: "pending") }
  scope :recent,  -> { order(created_at: :desc) }

  def pending? = status == "pending"
  def choice_label = CHOICE_LABELS[choice]

  def book!(lesson:, choice:, guardian: nil)
    update!(to_lesson: lesson, choice: choice, status: "booked",
            decided_by: guardian, decided_at: Time.current)
  end
end
