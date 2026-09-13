module Coach
  # Bảng công của tôi (FR-301) — chỉ đọc, số liệu do hệ thống tính từ điểm danh.
  class TimesheetController < BaseController
    RANGES = %w[day week month].freeze

    def index
      @range = RANGES.include?(params[:range]) ? params[:range] : "month"
      @anchor = parse_date(params[:date]) || Date.current
      @from, @to = bounds(@range, @anchor)

      @summary = PayrollCalculator.summary_for(teacher: current_teacher, from: @from, to: @to)
      @by_day = @summary[:entries].group_by { |e| e.lesson.date }.sort.reverse
      @locked_periods = PayrollPeriod.where.not(locked_at: nil)
                                     .where(id: TimesheetEntry.where(teacher_id: current_teacher.id)
                                                              .select(:payroll_period_id))
                                     .recent.limit(6).to_a
      @locked_totals = TimesheetEntry.where(teacher_id: current_teacher.id, status: "locked")
                                     .group(:payroll_period_id).sum(:amount)
    end

    private

    def nav_key = :timesheet

    def bounds(range, anchor)
      case range
      when "day"  then [anchor, anchor]
      when "week" then [anchor.beginning_of_week, anchor.end_of_week]
      else [anchor.beginning_of_month, anchor.end_of_month]
      end
    end

    def parse_date(value)
      Date.parse(value.to_s)
    rescue ArgumentError, TypeError
      nil
    end
  end
end
