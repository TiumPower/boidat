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
  # Tái ký cho học viên đã có hồ sơ — không tạo học viên mới (phụ huynh tự đăng
  # ký trên PWA, hoặc sale chọn học viên cũ).
  attribute :student_id, :integer
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

  validates :student_name, presence: { message: "Chưa nhập tên học viên" }, unless: :existing_student?
  validate  :guardian_required_for_child
  validate  :schedule_present
  validate  :package_present
  validate  :package_matches_class

  def adult_self_study? = ActiveModel::Type::Boolean.new.cast(adult_self_study)

  def child?
    return false if adult_self_study?
    return false if existing_student?   # học viên cũ đã có hộ và người giám hộ
    return true if birthdate.blank?
    ((Date.current - birthdate) / 365.25).floor < 16
  end

  # Học viên cũ: mọi thông tin (hộ, phụ huynh, hồ) lấy từ hồ sơ đang có.
  def student = @student ||= student_id.present? ? Student.find_by(id: student_id) : nil
  def existing_student? = student.present?

  def household
    @household ||= student&.household || (household_id.present? ? Household.find_by(id: household_id) : nil)
  end
  def guardian  = @guardian  ||= guardian_id.present? ? Guardian.find_by(id: guardian_id) : nil
  def swim_class = @swim_class ||= swim_class_id.present? ? SwimClass.find_by(id: swim_class_id) : nil
  def teacher = @teacher ||= swim_class&.teacher || (teacher_id.present? ? Teacher.find_by(id: teacher_id) : nil)

  # Khoá học lấy theo gói đã chọn — gói là thứ khách trả tiền, nên nó quyết định
  # nội dung học chứ không phải ngược lại.
  def course
    @course ||= swim_class&.course || package&.course ||
                (course_id.present? ? Course.find_by(id: course_id) : nil)
  end

  # Loại lớp cũng lấy theo gói: khách mua gói 1:1 thì phải được mở lớp 1:1, không
  # phải giá trị mặc định của form.
  def effective_class_type
    swim_class&.class_type || package&.class_type || class_type || 2
  end
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

  # Chống trường hợp khách trả tiền gói 1:1 nhưng bị xếp vào lớp 1:3 (hoặc ngược
  # lại) — đây là lỗi im lặng, chỉ lộ ra khi phụ huynh đến hồ và thấy lớp đông.
  def package_matches_class
    return if package.nil? || swim_class.nil?

    if package.class_type.present? && package.class_type != swim_class.class_type
      errors.add(:base, "Gói #{package.name} là lớp 1:#{package.class_type}, " \
                        "không khớp lớp 1:#{swim_class.class_type} bạn đang chọn")
    end
    if package.course_id.present? && swim_class.course_id.present? &&
       package.course_id != swim_class.course_id
      errors.add(:base, "Gói #{package.name} thuộc khoá #{package.course&.name}, " \
                        "không khớp khoá của lớp đã chọn")
    end
  end
end
