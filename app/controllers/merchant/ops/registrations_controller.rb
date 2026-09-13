module Merchant
  module Ops
    # Wizard đăng ký học viên vào một slot (FR-204).
    class RegistrationsController < BaseController
      def new
        @form = build_form
        load_options
      end

      def create
        @form = build_form(params[:registration])
        result = RegisterStudent.new(form: @form, workspace: current_workspace,
                                     pool: current_pool, actor: current_user).call
        if result.ok?
          audit!("create", result.enrollment,
                 summary: "Đăng ký #{result.student.name} vào lớp #{result.swim_class.code}")
          redirect_to merchant_ops_student_path(result.student),
                      notice: "Đã tạo lớp #{result.swim_class.code} cho #{result.student.name}. " \
                              "Đơn #{result.order.code} đang chờ thanh toán."
        else
          result.errors.each { |m| @form.errors.add(:base, m) unless @form.errors.full_messages.include?(m) }
          load_options
          render :new, status: :unprocessable_entity
        end
      end

      # Gợi ý hộ gia đình đang có khi sale gõ tên phụ huynh — tránh tạo trùng hộ
      # cho gia đình có nhiều con.
      def households
        q = params[:q].to_s.strip
        rows = if q.length >= 2
          Household.where("households.name ILIKE :q", q: "%#{q}%")
                   .or(Household.where(id: Guardian.where("guardians.name ILIKE :q OR guardians.phone ILIKE :q", q: "%#{q}%").select(:household_id)))
                   .includes(:guardians, :students).limit(8)
        else
          []
        end
        render json: rows.map { |h|
          { id: h.id, name: h.name,
            guardians: h.guardians.map { |g| { id: g.id, name: g.name, phone: g.phone } },
            students: h.students.map(&:name) }
        }
      end

      private

      def nav_key = :schedule

      def build_form(attrs = nil)
        form = RegistrationForm.new(attrs ? attrs.permit!.to_h : defaults_from_params)
        form.workspace = current_workspace
        form.pool = current_pool
        form
      end

      # Sale bấm vào một slot trống trên bảng lịch → điền sẵn giáo viên, giờ, thứ.
      def defaults_from_params
        {
          teacher_id: params[:teacher_id], start_hour: params[:hour],
          swim_class_id: params[:swim_class_id],
          start_date: params[:date].presence || Date.current.to_s,
          weekday_list: params[:date].present? ? Date.parse(params[:date]).wday.to_s : nil,
          class_type: params[:class_type].presence || 2
        }
      rescue ArgumentError
        {}
      end

      def load_options
        @teachers = ::Teacher.staff.active.in_pool(current_pool).includes(:user, :teacher_level).to_a
        @courses  = Course.active.ordered.to_a
        @packages = Package.sellable.ordered.includes(:course, :price_list_items).to_a
        @open_classes = SwimClass.running.classes.where(pool_id: current_pool.id)
                                 .includes(:teacher, :course, enrollments: :student).to_a
                                 .select { |c| c.seats_left.positive? }
        @promotions = Promotion.active.ordered.select { |p| p.pool_id.nil? || p.pool_id == current_pool.id }
        # Hộ gia đình đang có học viên ở hồ này — để gia đình nhiều con dùng chung
        # một mã QR thay vì bị tạo hộ mới mỗi lần đăng ký thêm bé.
        @households = Household.where(id: pool_scope(Student.all).select(:household_id))
                               .includes(:students).order(:name).limit(300).to_a
      end
    end
  end
end
