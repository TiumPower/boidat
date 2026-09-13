# Form object cho wizard đăng ký học viên (FR-204). Gom validate ở một chỗ để
# controller không phải gánh, và để test được luồng mà không cần đi qua HTTP.
#
# Hai đường vào:
#   · chọn SLOT TRỐNG  → mở lớp mới với giáo viên + khung giờ của slot đó
#   · chọn LỚP CÒN CHỖ → thêm học viên vào lớp nhóm đang chạy
class RegistrationForm
  include ActiveModel::Model
  include ActiveModel::Attributes

  attr_accessor :workspace, :pool

  # Học viên
  attribute :student_name, :string
  attribute :birthdate, :date
  attribute :gender, :string
  attribute :health_notes, :string
  attribute :source, :string

  # Phụ huynh — bắt buộc khi học viên là trẻ em (FR-204 bước 3)
  attribute :guardian_name, :string
  attribute :guardian_phone, :string
  attribute :guardian_email, :string
  attribute :guardian_relation, :string
  attribute :household_id, :integer
  attribute :guardian_id, :integer
  attribute :adult_self_study, :boolean, default: false

  # Lịch
  attribute :swim_class_id, :integer
  attribute :teacher_id, :integer
  attribute :course_id, :integer
  attribute :class_type, :integer, default: 2
  attribute :start_hour, :integer
  attribute :start_date, :date
  attribute :weekday_list, :string           # "1,3"

  # Tiền
  attribute :package_id, :integer
  attribute :discount, :integer, default: 0
  attribute :bonus_sessions, :integer, default: 0
  attribute :customer_type, :string, default: "new"

  validates :student_name, presence: { message: "Chưa nhập tên học viên" }
  validate  :guardian_required_for_child
  validate  :schedule_present
  validate  :package_present

  def adult_self_study? = ActiveModel::Type::Boolean.new.cast(adult_self_study)

  def child?
    return false if adult_self_study?
    return true if birthdate.blank?
    ((Date.current - birthdate) / 365.25).floor < 16
  end

  def household = @household ||= household_id.present? ? Household.find_by(id: household_id) : nil
  def guardian  = @guardian  ||= guardian_id.present? ? Guardian.find_by(id: guardian_id) : nil
  def swim_class = @swim_class ||= swim_class_id.present? ? SwimClass.find_by(id: swim_class_id) : nil
  def teacher = @teacher ||= swim_class&.teacher || (teacher_id.present? ? Teacher.find_by(id: teacher_id) : nil)
  def course  = @course  ||= swim_class&.course || (course_id.present? ? Course.find_by(id: course_id) : nil)
  def package = @package ||= package_id.present? ? Package.find_by(id: package_id) : nil

  def weekdays
    return swim_class.weekday_list if swim_class
    weekday_list.to_s.split(",").map(&:to_i).uniq.sort
  end

  def household_name
    return guardian_name.presence && "Gia đình #{guardian_name}" if guardian_name.present?
    student_name
  end

  # Giá chốt theo bảng giá của hồ tại thời điểm bán (Package#price_for).
  def price = package&.price_for(pool).to_i

  def total = [price - discount.to_i, 0].max

  private

  def guardian_required_for_child
    return unless child?
    return if household.present? || guardian.present?
    errors.add(:base, "Học viên là trẻ em — cần thông tin phụ huynh") if guardian_name.blank?
  end

  def schedule_present
    return if swim_class
    errors.add(:base, "Chưa chọn khung giờ học") if teacher_id.blank? || start_hour.blank?
    errors.add(:base, "Chưa chọn thứ trong tuần") if weekdays.empty?
    errors.add(:base, "Chưa chọn ngày bắt đầu") if start_date.blank?
  end

  def package_present
    errors.add(:base, "Chưa chọn gói học") if package.nil?
  end
end
