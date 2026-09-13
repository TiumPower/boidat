module Merchant
  module Ops
    # Bán vé lẻ nhanh cho khách vãng lai (FR-214). Vé là mã QR dùng một lần,
    # không đăng ký khuôn mặt (OQ-13) — xin đồng ý dữ liệu sinh trắc học cho một
    # lượt bơi là quá nặng so với giá trị giao dịch.
    class DayPassesController < BaseController
      def index
        @date = params[:date].present? ? Date.parse(params[:date]) : Date.current
        @tickets = DayPassTicket.where(pool_id: current_pool.id, valid_on: @date)
                                .order(created_at: :desc).to_a
        @packages = Package.active.where(kind: "day_pass").ordered.to_a
        @revenue = Order.where(pool_id: current_pool.id, kind: "day_pass", status: "paid")
                        .where(created_at: @date.all_day).sum(:amount)
      rescue ArgumentError
        redirect_to merchant_ops_day_passes_path
      end

      def create
        package = Package.find(params[:package_id])
        qty = [params[:quantity].to_i, 1].max
        amount = package.price_for(current_pool).to_i * qty

        ticket = nil
        ActiveRecord::Base.transaction do
          order = Order.create!(workspace: current_workspace, pool: current_pool, package: package,
                                sale: current_user, amount: amount, kind: "day_pass",
                                status: params[:paid] == "1" ? "paid" : "unpaid",
                                paid_at: params[:paid] == "1" ? Time.current : nil,
                                note: params[:guest_name])
          order.payments.create!(workspace: current_workspace, amount: amount,
                                 method: params[:method].presence || "cash",
                                 paid_at: Time.current, recorded_by: current_user) if order.paid?
          ticket = DayPassTicket.create!(workspace: current_workspace, pool: current_pool, order: order,
                                         issued_by: current_user, guest_name: params[:guest_name],
                                         guest_phone: params[:guest_phone], quantity: qty,
                                         valid_on: Date.current)
        end
        audit!("create", ticket, summary: "Bán vé lẻ #{ticket.code} ×#{qty}")
        redirect_to merchant_ops_day_passes_path, notice: "Đã tạo vé #{ticket.code} — đọc mã này cho quầy khi khách vào."
      end

      private

      def nav_key = :students
    end
  end
end
