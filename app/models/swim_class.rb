# Một lớp = một nhóm học viên học cố định với một giáo viên vào một khung giờ.
# Lớp chưa kết thúc khoá bị bộ xếp lịch tự động khoá cứng (OQ-08): học viên đã
# mua khoá 12 buổi thì không thể mỗi tuần lại bị đổi thầy đổi giờ.
class SwimClass < ApplicationRecord
  acts_as_tenant(:workspace)

  STATUSES = %w[running finished cancelled].freeze
  KINDS    = %w[class rental].freeze
  WEEKDAY_SHORT = %w[CN T2 T3 T4 T5 T6 T7].freeze

  belongs_to :workspace
  belongs_to :pool
  belongs_to :teacher
  belongs_to :course, optional: true
  has_many :lessons, dependent: :destroy
  has_many :enrollments, dependent: :destroy
  has_many :students, through: :enrollments

  validates :class_type, inclusion: { in: 1..4 }
  validates :start_hour, inclusion: { in: 0..23 }
  validates :status, inclusion: { in: STATUSES }
  validates :kind, inclusion: { in: KINDS }
  validate  :teacher_has_capacity

  before_create :assign_code

  scope :running, -> { where(status: "running") }
  scope :classes, -> { where(kind: "class") }
  scope :rentals, -> { where(kind: "rental") }

  # "Đang dạy" khác "chưa bị đóng". Một lớp dạy hết 12 buổi vẫn nằm nguyên ở
  # status "running" cho tới khi có người đóng nó, nên `running` một mình là
  # câu trả lời sai cho câu hỏi "lớp này còn hoạt động không".
  #
  # Chỗ này từng gây hai hậu quả thật: bộ xếp lịch coi khung giờ của lớp đã dạy
  # xong là vùng cấm nên không bao giờ xếp lại được (6/16 khung của Hồ Quận 7
  # bị khoá vĩnh viễn), và PWA phụ huynh vẫn chào bán chỗ trống của những lớp
  # không còn buổi nào để học.
  # Nghi ngờ thì coi là CÒN hoạt động. Lớp vừa tạo mà chưa kịp sinh buổi cũng
  # phải giữ chỗ: đoán nhầm theo hướng "đã xong" nghĩa là bộ xếp lịch xếp đè
  # lên giáo viên đang có lớp, tệ hơn hẳn việc để trống một khung.
  scope :teaching, lambda {
    over = joins(:lessons).group("swim_classes.id")
                          .having("MAX(lessons.date) < ?", Date.current)
                          .select("swim_classes.id")
    running.where.not(id: over)
  }

  def running? = status == "running"
  def rental?  = kind == "rental"

  # Đã dạy hết giáo trình: có buổi, và buổi cuối cùng đã ở quá khứ. Lớp chưa
  # sinh buổi nào thì KHÔNG tính là xong — nó chỉ chưa bắt đầu.
  def course_over?
    running? && lessons.exists? && lessons.where("date >= ?", Date.current).none?
  end

  def weekday_list = Array(weekdays).map(&:to_i).sort
  def weekday_label = weekday_list.map { |w| WEEKDAY_SHORT[w] }.join(" & ")
  def time_label = format("%02d:00", start_hour)
  def slot_label = "#{weekday_label} · #{time_label}"

  def label = "#{slot_label} — lớp #{code}"

  # Sức chứa lấy theo loại lớp, nhưng không vượt quá level của giáo viên (BR-04).
  def capacity = [class_type, teacher.capacity].min
  def active_enrollments = enrollments.select { |e| e.status == "active" }
  def seats_taken = active_enrollments.size
  def seats_left  = [capacity - seats_taken, 0].max
  def full? = seats_left.zero?

  def total_sessions = course&.total_sessions || workspace.course_session_count

  # Buổi gần nhất đã diễn ra — dùng để hiện "buổi thứ mấy" trên bảng lịch.
  def current_session_index
    lessons.select { |l| l.status == "done" }.map(&:session_index).compact.max ||
      lessons.select { |l| l.date <= Date.current }.map(&:session_index).compact.max || 0
  end

  private

  # Mã lớp ngắn hiển thị trên bảng master data (#4821 trong bộ UX).
  def assign_code
    self.code ||= loop do
      candidate = rand(1000..9999).to_s
      break "##{candidate}" unless SwimClass.unscoped.exists?(code: "##{candidate}")
    end
  end

  def teacher_has_capacity
    return if teacher.nil? || class_type.nil? || teacher.renter?
    return if class_type <= teacher.capacity
    errors.add(:class_type, "vượt sức chứa của #{teacher.level_label} (tối đa #{teacher.capacity} học viên/tiết)")
  end
end
