module Merchant
  module Ops
    # Bảng master data lịch học (FR-202) — màn hình chính của cổng vận hành.
    # P0 dựng khung + khung giờ của hồ; lớp/buổi học nối vào ở P2.
    class ScheduleController < BaseController
      VIEWS = %w[day week month].freeze

      def index
        @view = VIEWS.include?(params[:view]) ? params[:view] : "week"
        @anchor = parse_date(params[:date]) || Date.current
        @days = days_for(@view, @anchor)
        @hours = @days.flat_map { |d| current_pool.slot_hours_on(d) }.uniq.sort
        @teachers = ::Teacher.staff.active.in_pool(current_pool).includes(:teacher_level, :user).to_a
      end

      private

      def nav_key = :schedule

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
