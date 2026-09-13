module Merchant
  module Bod
    # Báo cáo & xuất file (FR-103). BOD thường cần file để mang đi họp, nên xuất
    # đúng bộ lọc đang xem chứ không phải một bản mặc định khác.
    class ReportsController < BaseController
      def index
        @period = PeriodFilter.new(params[:period], params[:from], params[:to])
        @pools = accessible_pools
        @scope_pool = params[:pool_id].presence
        metrics = PoolMetrics.new(workspace: current_workspace, pools: report_pools, period: @period)
        @stats = metrics.call
        @by_pool = metrics.by_pool
        @teachers = metrics.teacher_ranking(limit: 30)
        @packages = metrics.package_ranking(limit: 20)

        respond_to do |format|
          format.html
          format.xlsx do
            audit!("read_sensitive", current_workspace,
                   summary: "Xuất báo cáo #{@period.range_label}")
            response.headers["Content-Disposition"] =
              %(attachment; filename="baocao-#{@period.from}-#{@period.to}.xlsx")
          end
          format.csv do
            send_data csv_export, filename: "baocao-#{@period.from}-#{@period.to}.csv",
                      type: "text/csv; charset=utf-8"
          end
        end
      end

      private

      def nav_key = :reports

      # CSV có BOM UTF-8 — không có nó thì Excel trên Windows mở ra tiếng Việt
      # thành ký tự lỗi, và đó là thứ đầu tiên khách phàn nàn.
      def csv_export
        require "csv"
        csv = CSV.generate do |out|
          out << ["Báo cáo", current_workspace.name, @period.range_label]
          out << []
          out << ["Chỉ số", "Giá trị"]
          out << ["Doanh thu khoá học", @stats[:revenue_course]]
          out << ["Doanh thu cho thuê hồ", @stats[:revenue_rental]]
          out << ["Học viên đang học", @stats[:students_active]]
          out << ["Học viên mới trong kỳ", @stats[:students_new]]
          out << ["Số khoá đang chạy", @stats[:courses_running]]
          out << ["Số tiết đã dạy", @stats[:lessons_taught]]
          out << ["Tổng công giáo viên", @stats[:credits]]
          out << ["Tỷ lệ lấp đầy (%)", @stats[:fill_rate]]
          out << ["Chi tiết lấp đầy", @stats[:fill_detail]]
          out << ["Vắng không báo (%)", @stats[:no_show_rate]]
          out << ["Đang chờ thu", @stats[:unpaid_amount]]
          out << []
          out << ["Hồ bơi", "Doanh thu", "Tỷ lệ lấp đầy", "Học viên"]
          @by_pool.each { |row| out << [row[:pool].name, row[:revenue], "#{row[:fill_rate]}%", row[:students]] }
          out << []
          out << ["Giáo viên", "Cấp độ", "Công"]
          @teachers.each { |row| out << [row[:teacher].display_name, row[:teacher].level_label, row[:credits]] }
        end
        "﻿#{csv}"
      end
    end
  end
end
