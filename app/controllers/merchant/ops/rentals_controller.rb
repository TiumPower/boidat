module Merchant
  module Ops
    # Lớp thuê hồ (FR-225) — mô hình kinh doanh thứ hai chạy song song.
    #
    # Trung tâm KHÔNG quản lý giáo án, level, chấm công, nhận xét hay xếp lịch tự
    # động cho nhóm này. Chỉ quản lý: khung giờ họ thuê (để slot hiện "đã bận"
    # trên bảng master data), danh sách học viên của họ, và điểm danh trừ buổi.
    class RentalsController < BaseController
      def index
        @rentals = SwimClass.rentals.where(pool_id: current_pool.id)
                            .includes(:teacher, enrollments: :student).to_a
        @revenue_month = Order.where(pool_id: current_pool.id, kind: "rental", status: "paid")
                              .where(created_at: Date.current.all_month).sum(:amount)
        @students = Student.renters.where(pool_id: current_pool.id).includes(:face_profile).to_a
      end

      def new
        @renters = ::Teacher.renter.active.in_pool(current_pool).includes(:user).to_a
        @rental = SwimClass.new(workspace: current_workspace, pool: current_pool,
                                kind: "rental", class_type: 4, start_date: Date.current)
      end

      def create
        teacher = ::Teacher.renter.find(params[:teacher_id])
        weekdays = Array(params[:weekdays]).map(&:to_i)
        rental = SwimClass.new(workspace: current_workspace, pool: current_pool, teacher: teacher,
                               kind: "rental", class_type: params[:class_type].presence || 4,
                               start_hour: params[:start_hour], weekdays: weekdays,
                               start_date: params[:start_date].presence || Date.current,
                               status: "running")
        if rental.save
          LessonGenerator.new(rental).call(total: params[:sessions].presence&.to_i || 24)
          create_rental_order(rental, params[:hourly_rate].to_i, params[:hours].to_i)
          audit!("create", rental, summary: "Tạo lịch thuê hồ cho #{teacher.display_name}")
          redirect_to merchant_ops_rental_path(rental), notice: "Đã tạo lịch thuê hồ."
        else
          @renters = ::Teacher.renter.active.in_pool(current_pool).includes(:user).to_a
          @rental = rental
          render :new, status: :unprocessable_entity
        end
      end

      def show
        @rental = SwimClass.rentals.where(pool_id: current_pool.id)
                           .includes(enrollments: :student, lessons: :attendances).find(params[:id])
        @orders = Order.where(pool_id: current_pool.id, kind: "rental").recent.limit(12).to_a
      end

      private

      def nav_key = :rentals

      # Doanh thu thuê hồ ghi thành dòng riêng để dashboard tách bạch được với
      # doanh thu khoá học — hai mô hình có biên lợi nhuận rất khác nhau (OQ-26).
      def create_rental_order(rental, hourly_rate, hours)
        return if hourly_rate.zero? || hours.zero?
        Order.create!(workspace: current_workspace, pool: current_pool, sale: current_user,
                      amount: hourly_rate * hours, kind: "rental", status: "unpaid",
                      note: "#{rental.teacher.display_name} · #{hours} giờ × #{hourly_rate}đ")
      end
    end
  end
end
