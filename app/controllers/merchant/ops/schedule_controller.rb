module Merchant
  module Ops
    # Bảng master data lịch học (FR-202, FR-203) — một màn hình duy nhất, không
    # tách "trang chủ" và "màn hình lịch". Hiện cả slot đã có lớp lẫn slot còn
    # trống để sale chốt lịch được ngay tại đây.
    class ScheduleController < BaseController
      VIEWS = %w[day week month].freeze

      def index
        @view   = VIEWS.include?(params[:view]) ? params[:view] : "week"
        @anchor = parse_date(params[:date]) || Date.current
        @days   = days_for(@view, @anchor)
        @q      = params[:q].to_s.strip
        @only_free = params[:free] == "1"

        @board = ScheduleBoard.new(pool: current_pool, days: @days, teacher_scope: teacher_scope)
        @slots = filtered_slots
        @summary = @board.summary
        @kpis = load_kpis
      end

      # Chi tiết một slot: bảng lịch mở panel này để sale xem lớp / chốt học viên
      # mới, và để admin điểm danh tay khi nhận diện khuôn mặt thất bại (FR-234).
      def slot
        @date = parse_date(params[:date]) or return head(:bad_request)
        @hour = params[:hour].to_i
        @teacher = ::Teacher.in_pool(current_pool).find(params[:teacher_id])
        @lesson = Lesson.where(pool_id: current_pool.id, date: @date, start_hour: @hour,
                               teacher_id: @teacher.id).where.not(status: "cancelled").first
        @swim_class = @lesson&.swim_class
        render layout: false
      end

      private

      def nav_key = :schedule

      # Tìm theo tên giáo viên → ra toàn bộ lịch của giáo viên đó (FR-203).
      def teacher_scope
        scope = ::Teacher.in_pool(current_pool).where(status: %w[active on_leave])
        return scope if @q.blank?
        matched = scope.joins(:user).where("users.name ILIKE :q", q: "%#{@q}%")
        matched.exists? ? matched : scope
      end

      # Tìm theo tên học viên → chỉ giữ slot có em đó; lọc slot trống là bộ lọc
      # được dùng nhiều nhất khi xếp lịch cho khách mới.
      def filtered_slots
        slots = @board.slots
        slots = slots.select(&:free?) if @only_free
        if @q.present?
          by_student = slots.select do |s|
            s.swim_class&.active_enrollments&.any? { |e| e.student.name.match?(/#{Regexp.escape(@q)}/i) }
          end
          slots = by_student if by_student.any?
        end
        slots
      end

      def load_kpis
        running = SwimClass.teaching.classes.where(pool_id: current_pool.id).count
        # Đếm ĐẦU NGƯỜI, không đếm lượt ghi danh: một em tái ký hai lần vẫn là
        # một học viên. Đếm enrollment làm hồ Quận 7 báo 36 trong khi cả trung
        # tâm chỉ có 23 em — con số khách bắt được ngay.
        students = Enrollment.active.where(pool_id: current_pool.id).distinct.count(:student_id)
        low = Enrollment.active.where(pool_id: current_pool.id)
                        .select { |e| e.low_sessions? }.size
        { classes: running, students: students, free_slots: @board.free_slots.size,
          low_sessions: low,
          unpaid_orders: Order.unpaid.where(pool_id: current_pool.id).count }
      end

      def parse_date(value)
        Date.parse(value.to_s)
      rescue ArgumentError, TypeError
        nil
      end

      def days_for(view, anchor)
        case view
        when "day"   then [anchor]
        when "month" then (anchor.beginning_of_month..anchor.end_of_month).to_a
        else (anchor.beginning_of_week..anchor.end_of_week).to_a
        end
      end
    end
  end
end
