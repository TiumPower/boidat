module Merchant
  module Ops
    # Tab chấm công (FR-210). Màn hình CHỈ ĐỌC — số liệu do hệ thống tính từ dữ
    # liệu điểm danh, không ai nhập tay. Admin chỉ có một hành động: chốt kỳ.
    class TimesheetsController < BaseController
      def index
        @from = parse_date(params[:from]) || Date.current.beginning_of_month
        @to   = parse_date(params[:to])   || Date.current.end_of_month

        @entries = TimesheetEntry.where(pool_id: current_pool.id)
                                 .in_range(@from, @to)
                                 .includes(:teacher, :lesson, teacher: :user).to_a
        @by_teacher = @entries.group_by(&:teacher).map do |teacher, rows|
          { teacher: teacher, lessons: rows.size, credits: rows.sum(&:credits),
            amount: rows.sum(&:amount), locked: rows.count(&:locked?) }
        end.sort_by { |r| -r[:credits] }

        @totals = { credits: @entries.sum(&:credits), amount: @entries.sum(&:amount),
                    lessons: @entries.size, pending: @entries.count { |e| !e.locked? } }
        @periods = PayrollPeriod.where(pool_id: current_pool.id).recent.limit(8).to_a
      end

      # Chốt công kỳ: khoá các dòng công trong khoảng, sửa điểm danh sau đó không
      # làm thay đổi số tiền đã chốt.
      def lock
        from = parse_date(params[:from]) or return redirect_to(merchant_ops_timesheets_path, alert: "Thiếu ngày bắt đầu.")
        to   = parse_date(params[:to])   or return redirect_to(merchant_ops_timesheets_path, alert: "Thiếu ngày kết thúc.")

        period = PayrollPeriod.create!(workspace: current_workspace, pool: current_pool,
                                       starts_on: from, ends_on: to)
        period.lock!(by: current_user)
        notify_teachers(period)
        audit!("update", period, summary: "Chốt công kỳ #{period.label}")
        redirect_to merchant_ops_timesheets_path(from: from, to: to),
                    notice: "Đã chốt kỳ #{period.label} · #{period.total_credits.to_f.round(1)} công · #{vnd_amount(period.total_amount)}."
      end

      private

      def nav_key = :teachers

      def vnd_amount(n) = "#{ActiveSupport::NumberHelper.number_to_delimited(n.to_i)}đ"

      def notify_teachers(period)
        teacher_ids = period.timesheet_entries.pluck(:teacher_id).uniq
        return if teacher_ids.empty?
        users = ::Teacher.where(id: teacher_ids).includes(:user).map(&:user)
        title = "Đã chốt công kỳ #{period.label}"
        users.each do |u|
          Notification.create!(workspace: current_workspace, recipient: u, kind: "payroll",
                               title: title, body: "Xem chi tiết trong mục Bảng công.",
                               subject: period, deep_link: "/teacher/timesheet")
        end
        PushJob.perform_later(current_workspace.id, "User", users.map(&:id), title,
                              "Xem chi tiết trong mục Bảng công.", "/teacher/timesheet")
      end

      def parse_date(value)
        Date.parse(value.to_s)
      rescue ArgumentError, TypeError
        nil
      end
    end
  end
end
