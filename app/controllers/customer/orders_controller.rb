module Customer
  # Hoá đơn của hộ + thanh toán bằng mã QR PayOS (FR-408).
  class OrdersController < BaseController
    before_action :require_guardian!
    before_action :require_payment_access!   # OQ-03 — người đưa đón không xem tiền
    before_action :set_order, only: [:show, :pay, :return]

    def index
      @orders = Order.where(household_id: current_household.id)
                     .includes(:student, :package).recent.to_a
      @unpaid = @orders.select(&:unpaid?)
    end

    def show; end

    # Mở phiên thanh toán: sinh link PayOS mới rồi chuyển sang trang QR của họ.
    def pay
      result = PayosCheckout.new(@order,
                                 return_url: member_order_return_url(@order, **url_host),
                                 cancel_url: member_order_return_url(@order, cancel: true, **url_host)).call
      if result.ok?
        redirect_to result.checkout_url, allow_other_host: true
      else
        redirect_to member_order_path(@order), alert: result.error
      end
    end

    # PayOS chuyển về đây sau khi thanh toán hoặc huỷ. Webhook có thể về trễ nên
    # màn hình này hỏi lại PayOS thay vì bắt phụ huynh ngồi đợi trạng thái nhảy.
    def return
      @cancelled = params[:cancel] == "true" || params[:status] == "CANCELLED"
      @paid = @cancelled ? false : PayosCheckout.confirm!(@order)
    end

    private

    def set_order
      @order = Order.where(household_id: current_household.id).find(params[:id])
    end

    def url_host
      { host: request.host_with_port, protocol: request.protocol,
        workspace_slug: params[:workspace_slug] }.compact
    end
  end
end
