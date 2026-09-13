module Merchant
  module Ops
    # Sale/Admin xem hồ sơ giáo viên của hồ đang trực (chỉ đọc — sửa hồ sơ là
    # quyền của BOD). Tab chấm công và đơn xin nghỉ nối vào ở P3/P6.
    class TeachersController < BaseController
      # Dùng chung cho thanh tab của cả ba màn hình giáo viên / chấm công / đơn nghỉ.
      def self.pending_leave_count(pool)
        return 0 if pool.nil?
        LeaveRequest.pending.where(teacher_id: ::Teacher.in_pool(pool).select(:id)).count
      end

      def index
        @teachers = ::Teacher.in_pool(current_pool).includes(:user, :teacher_level).order(:kind).to_a
        @next_month = Date.current.next_month.beginning_of_month
        rows = TeacherAvailability.for_month(@next_month).where(pool_id: current_pool.id)
        @availability = rows.group(:teacher_id).count
        @submitted = rows.submitted.distinct.pluck(:teacher_id).to_set
        @deadline = (@next_month - 1.month).change(
          day: [current_workspace.availability_deadline_day, (@next_month - 1.month).end_of_month.day].min
        )
      end

      def show
        @teacher = ::Teacher.in_pool(current_pool).find(params[:id])
        @next_month = Date.current.next_month.beginning_of_month
        @availability_count = TeacherAvailability.for_month(@next_month)
                                                 .where(teacher: @teacher, pool: current_pool).count
        @submitted = TeacherAvailability.for_month(@next_month)
                                        .where(teacher: @teacher).submitted.exists?
      end

      # Giáo viên tự đăng ký lịch trên PWA là đường chính, nhưng thực tế luôn có
      # người quên hoặc không dùng app — admin phải set hộ được, nếu không cả hồ
      # đứng chờ một người (FR-217).
      def availability
        @teacher = ::Teacher.in_pool(current_pool).find(params[:id])
        @month = parse_month(params[:month]) || Date.current.next_month.beginning_of_month
        @hours = pool_hours

        if request.patch?
          count = TeacherAvailability.replace_month!(
            teacher: @teacher, month: @month,
            slots: Array(params[:slots]).select { |s| s.to_s.start_with?("#{current_pool.id}:") },
            submitted: true
          )
          audit!("update", @teacher,
                 summary: "Admin set lịch dạy tháng #{@month.strftime('%m/%Y')} cho #{@teacher.display_name} · #{count} ca")
          return redirect_to availability_merchant_ops_teacher_path(@teacher, month: @month.strftime("%Y-%m")),
                             notice: "Đã lưu #{count} ca cho #{@teacher.display_name}."
        end

        @selected = TeacherAvailability.for_month(@month)
                                       .where(teacher: @teacher, pool: current_pool)
                                       .pluck(:weekday, :hour).map { |wd, h| "#{current_pool.id}:#{wd}:#{h}" }.to_set
        @conflicts = TeacherAvailability.conflicts_for(@teacher, @month)
      end

      private

      def nav_key = :teachers

      def pool_hours
        (0..6).flat_map { |wd| current_pool.slot_hours_on(Date.current.beginning_of_week + ((wd - 1) % 7)) }
              .uniq.sort
      end

      def parse_month(value)
        return nil if value.blank?
        Date.strptime(value, "%Y-%m")
      rescue ArgumentError
        nil
      end
    end
  end
end
