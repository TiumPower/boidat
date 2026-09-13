module Merchant
  module Ops
    # Đơn hàng & thanh toán (FR-220, FR-223). Admin vẫn cập nhật trạng thái thủ
    # công được cho trường hợp thu tiền mặt hoặc chuyển khoản ngoài hệ thống.
    class OrdersController < BaseController
      before_action :set_order, only: [:show, :mark_paid, :checkout]

      def index
        @status = Order::STATUSES.include?(params[:status]) ? params[:status] : nil
        @q = params[:q].to_s.strip
        scope = Order.where(pool_id: current_pool.id).includes(:student, :household, :package, :sale)
        scope = scope.where(status: @status) if @status
        if @q.present?
          scope = scope.where("orders.code ILIKE :q", q: "%#{@q}%")
                       .or(scope.where(student_id: Student.where("students.name ILIKE :q", q: "%#{@q}%")))
        end
        @orders = scope.recent.limit(200).to_a
        @counts = Order.where(pool_id: current_pool.id).group(:status).count
        @totals = {
          course: Order.where(pool_id: current_pool.id).course_revenue.sum(:amount),
          rental: Order.where(pool_id: current_pool.id).rental_revenue.sum(:amount),
          unpaid: Order.where(pool_id: current_pool.id).unpaid.sum(:amount)
        }
      end

      def show
        @payments = @order.payments.order(:paid_at).to_a
      end

      # Thu tiền mặt / chuyển khoản ngoài hệ thống.
      def mark_paid
        if @order.apply_payment!(method: params[:method].presence || "cash", recorded_by: current_user)
          audit!("update", @order, summary: "Ghi nhận thanh toán #{@order.code} (#{params[:method]})")
          redirect_to merchant_ops_order_path(@order), notice: "Đã ghi nhận thanh toán."
        else
          redirect_to merchant_ops_order_path(@order), alert: "Đơn này đã thanh toán rồi."
        end
      end

      # Sinh lại link PayOS để đọc/gửi cho phụ huynh.
      def checkout
        result = PayosCheckout.new(@order,
                                   return_url: merchant_ops_order_url(@order),
                                   cancel_url: merchant_ops_order_url(@order, cancel: true)).call
        if result.ok?
          redirect_to merchant_ops_order_path(@order), notice: "Đã tạo liên kết thanh toán mới."
        else
          redirect_to merchant_ops_order_path(@order), alert: result.error
        end
      end

      private

      def nav_key = :orders
      def set_order = @order = Order.where(pool_id: current_pool.id).find(params[:id])
    end
  end
end
