module Merchant
  module Ops
    # Bộ xếp lịch tự động (FR-205). Luôn dừng ở bản nháp: admin xem trước, bỏ bớt
    # dòng không ưng, rồi mới Áp dụng. Không bao giờ ghi thẳng vào lịch thật.
    class ScheduleRunsController < BaseController
      before_action :require_scheduler_access!
      before_action :set_run, only: [:show, :apply, :discard]

      def index
        @month = parse_month(params[:month]) || Date.current.next_month.beginning_of_month
        @runs = ScheduleRun.where(pool_id: current_pool.id).recent.limit(12).to_a
        @current = ScheduleRun.where(pool_id: current_pool.id, month: @month).recent.first
        @readiness = readiness(@month)
      end

      def create
        month = parse_month(params[:month]) || Date.current.next_month.beginning_of_month
        run = AutoScheduler.new(pool: current_pool, month: month, workspace: current_workspace)
                           .build_draft(created_by: current_user)
        audit!("create", run, summary: "Chạy xếp lịch tháng #{run.month_label}")
        redirect_to merchant_ops_schedule_run_path(run),
                    notice: "Đã tạo bản nháp #{run.proposal_rows.size} khung giờ. Xem lại rồi mới áp dụng."
      end

      def show
        @rows = @run.proposal_rows
        @by_teacher = @rows.group_by { |r| r[:teacher_name] }
      end

      def apply
        keep = Array(params[:keep])
        count = @run.apply!(by: current_user, keep: keep.presence)
        audit!("update", @run, summary: "Áp dụng lịch tháng #{@run.month_label} · #{count} khung")
        redirect_to merchant_ops_schedule_runs_path(month: @run.month.strftime("%Y-%m")),
                    notice: "Đã áp dụng #{count} khung giờ. Sale có thể chốt học viên vào các slot này."
      end

      def discard
        @run.discard!(by: current_user)
        redirect_to merchant_ops_schedule_runs_path, notice: "Đã bỏ bản nháp."
      end

      private

      def nav_key = :auto_schedule

      def require_scheduler_access!
        return unless feature_locked?(:auto_scheduler)
        redirect_to merchant_ops_root_path,
                    alert: "Gói hiện tại chưa có bộ xếp lịch tự động."
      end

      def set_run = @run = ScheduleRun.where(pool_id: current_pool.id).find(params[:id])

      # Hai đầu vào bắt buộc — thiếu cái nào thì nói rõ, đừng để admin bấm chạy
      # rồi nhận về bản nháp trống mà không hiểu vì sao.
      def readiness(month)
        teachers = ::Teacher.staff.active.in_pool(current_pool).count
        submitted = TeacherAvailability.for_month(month).where(pool_id: current_pool.id)
                                       .submitted.distinct.count(:teacher_id)
        {
          teachers: teachers,
          submitted: submitted,
          running_classes: SwimClass.running.where(pool_id: current_pool.id).count,
          ready: submitted.positive?
        }
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
