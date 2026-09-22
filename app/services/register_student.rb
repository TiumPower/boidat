# Đăng ký học viên vào một slot (FR-204). Một thao tác của sale phải sinh ra
# trọn bộ dữ liệu, nếu không hệ thống sẽ có học viên mà không có lớp, hoặc lớp
# mà không có đơn hàng:
#
#   hồ sơ học viên → hộ gia đình + người giám hộ + mã QR → lớp học (mới hoặc
#   vào lớp còn chỗ) → các buổi học → đăng ký học (số buổi, hạn dùng) →
#   đơn hàng "chưa thanh toán" → thông báo cho giáo viên và phụ huynh (FR-222).
#
# Toàn bộ nằm trong một transaction: hỏng ở bước nào thì không để lại rác.
class RegisterStudent
  Result = Struct.new(:ok, :student, :swim_class, :enrollment, :order, :errors, keyword_init: true) do
    def ok? = ok
  end

  # form: RegistrationForm
  def initialize(form:, workspace:, pool:, actor: nil)
    @form = form
    @workspace = workspace
    @pool = pool
    @actor = actor
  end

  def call
    return failure(@form.errors.full_messages) unless @form.valid?

    ActiveRecord::Base.transaction do
      @household  = find_or_build_household
      @guardian   = find_or_build_guardian
      @student    = build_student
      @swim_class = @form.swim_class || existing_class_in_slot || build_class
      ensure_capacity!
      @enrollment = build_enrollment
      LessonGenerator.new(@swim_class).call
      @order = build_order
      notify!
    end

    Result.new(ok: true, student: @student, swim_class: @swim_class,
               enrollment: @enrollment, order: @order, errors: [])
  rescue ActiveRecord::RecordInvalid => e
    failure(Array(e.record&.errors&.full_messages).presence || [e.message])
  rescue CapacityError => e
    failure([e.message])
  end

  private

  class CapacityError < StandardError; end

  def failure(messages) = Result.new(ok: false, errors: Array(messages))

  # Học viên cũ tái ký thì gắn vào đúng hộ đang có, không đẻ thêm hộ mới.
  def find_or_build_household
    return @form.household if @form.household

    Household.create!(workspace: @workspace, kind: @form.adult_self_study? ? "individual" : "family",
                      name: @form.household_name)
  end

  def find_or_build_guardian
    return @form.guardian if @form.guardian
    return @household.owner if @household.guardians.any? && @form.guardian_name.blank?

    Guardian.create!(workspace: @workspace, household: @household,
                     name: @form.guardian_name.presence || @form.student_name,
                     phone: @form.guardian_phone, email: @form.guardian_email,
                     relation: @form.guardian_relation, role: "owner",
                     is_student: @form.adult_self_study?)
  end

  # Tái ký thì KHÔNG tạo hồ sơ mới — nhân bản học viên là cách nhanh nhất để mất
  # dấu lịch sử học và làm hỏng thống kê.
  def build_student
    return @form.student if @form.existing_student?

    Student.create!(
      workspace: @workspace, household: @household, pool: @pool,
      guardian: @form.adult_self_study? ? @guardian : nil,
      name: @form.student_name, birthdate: @form.birthdate, gender: @form.gender,
      health_notes: @form.health_notes, source: @form.source,
      kind: "center", status: "active"
    )
  end

  # Sale chọn slot chứ không chọn lớp, nên trước khi mở lớp mới phải xem khung
  # giờ đó đã có lớp đang chạy chưa. Không kiểm là mỗi lần đăng ký lại đẻ thêm
  # một lớp chồng lên lớp cũ: giáo viên đứng hai lớp cùng giờ, bảng master data
  # chỉ vẽ được một ô nên lớp thứ hai vô hình, mà công vẫn tính cho cả hai.
  def existing_class_in_slot
    return nil if @form.teacher.nil?

    SwimClass.running.classes
             .where(pool_id: @pool.id, teacher_id: @form.teacher.id, start_hour: @form.start_hour)
             .detect do |cls|
               cls.class_type == @form.effective_class_type &&
                 (cls.weekday_list & Array(@form.weekdays).map(&:to_i)).any? &&
                 !cls.course_over?
             end
  end

  # Slot trống → mở lớp mới với giáo viên và khung giờ của slot đó.
  def build_class
    SwimClass.create!(
      workspace: @workspace, pool: @pool, teacher: @form.teacher, course: @form.course,
      class_type: @form.effective_class_type, start_hour: @form.start_hour,
      weekdays: @form.weekdays, start_date: @form.start_date, status: "running", kind: "class"
    )
  end

  # Lớp nhóm còn chỗ thì thêm học viên vào; hết chỗ phải báo rõ chứ không âm thầm
  # nhét thêm — quá sĩ số là vi phạm ràng buộc level của giáo viên (BR-04).
  def ensure_capacity!
    return if @swim_class.seats_left.positive?
    raise CapacityError, "Lớp #{@swim_class.code} đã đủ #{@swim_class.capacity} học viên."
  end

  def build_enrollment
    Enrollment.create!(
      workspace: @workspace, pool: @pool, student: @student, swim_class: @swim_class,
      package: @form.package, starts_on: @swim_class.start_date,
      sessions_total: @form.package&.session_count || @swim_class.total_sessions,
      bonus_sessions: @form.bonus_sessions, customer_type: @form.customer_type, status: "active"
    )
  end

  def build_order
    price = @form.price
    Order.create!(
      workspace: @workspace, pool: @pool, household: @household, student: @student,
      enrollment: @enrollment, package: @form.package, sale: @actor,
      amount: price, discount: @form.discount,
      kind: @form.customer_type == "returning" ? "renewal" : "course",
      customer_type: @form.customer_type, status: "unpaid"
    )
  end

  # FR-222 — bắn ngay khi xác nhận tạo lớp, không đợi tới bước ký cam kết.
  # Hai nhóm người nhận, hai nội dung khác nhau.
  def notify!
    ClassCreatedNotifier.new(enrollment: @enrollment).call
  end
end
