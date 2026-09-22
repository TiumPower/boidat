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
  validate  :teacher_slot_is_free

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

  # Ngày lớp này còn giữ khung giờ tới. Chưa khai end_date thì lấy buổi cuối
  # cùng đã sinh; chưa sinh buổi nào thì coi như giữ vô thời hạn (đoán nhầm theo
  # hướng "còn giữ" an toàn hơn — xem ghi chú ở scope `teaching`).
  FAR_FUTURE = Date.new(9999, 12, 31)

  def occupied_until = end_date || lessons.maximum(:date) || FAR_FUTURE

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

  # Một giáo viên không thể đứng hai lớp cùng giờ cùng thứ. Trước đây không có
  # ràng buộc nào: dữ liệu demo có 5 cặp lớp chồng nhau, bảng master data chỉ vẽ
  # được MỘT ô cho mỗi (giáo viên, giờ) nên lớp thứ hai vô hình với vận hành —
  # chỉ giáo viên nhìn thấy trên PWA, và công thì vẫn tính cho cả hai.
  def teacher_slot_is_free
    return if teacher_id.nil? || start_hour.nil? || !running?

    clash = SwimClass.where(teacher_id: teacher_id, start_hour: start_hour, status: "running")
                     .where.not(id: id)
                     .detect { |other| (other.weekday_list & weekday_list).any? && overlaps_dates?(other) }
    return if clash.nil?

    errors.add(:base, "#{teacher.display_name} đã có lớp #{clash.code} vào #{clash.slot_label}")
  end

  # Hai lớp chỉ thực sự đụng nhau khi khoảng ngày của chúng giao nhau — lớp cũ
  # đã dạy xong thì khung giờ đó trống cho lớp mới.
  def overlaps_dates?(other)
    return true if start_date.nil? || other.start_date.nil?

    start_date <= other.occupied_until && other.start_date <= occupied_until
  end
end
