# Mở phiên thanh toán PayOS cho một đơn hàng của trung tâm (FR-223).
#
# Luồng đã chốt với khách: Admin/Sale tạo đơn trước (trạng thái "Chưa thanh
# toán") → đơn hiện trên PWA phụ huynh → phụ huynh bấm thanh toán → hiện mã QR
# PayOS → webhook trả kết quả → hệ thống tự đổi trạng thái. Admin vẫn sửa trạng
# thái thủ công được cho tiền mặt / chuyển khoản ngoài.
#
# Bốn tình huống lệch phải xử lý (FR-223 bước 6): mã QR hết hạn, phụ huynh đóng
# màn hình giữa chừng, webhook về trễ, và webhook về hai lần.
class PayosCheckout
  Result = Struct.new(:ok, :checkout_url, :error, keyword_init: true) do
    def ok? = ok
  end

  def initialize(order, return_url:, cancel_url:)
    @order = order
    @return_url = return_url
    @cancel_url = cancel_url
  end

  def call
    service = PayosService.new
    return failure("Cổng thanh toán PayOS chưa được cấu hình.") unless service.configured?
    return failure("Đơn này đã thanh toán rồi.") if @order.paid?

    # Mã đơn mới mỗi lần mở checkout: link cũ đã huỷ hoặc hết hạn không được
    # chặn lần thanh toán sau ("đơn hàng đã được xử lý" phía PayOS).
    @order.reassign_payos_code!

    data = service.create_payment_link(
      order_code: @order.payos_order_code,
      amount: @order.total,
      description: description,
      return_url: @return_url,
      cancel_url: @cancel_url
    )
    if data && data["checkoutUrl"].present?
      @order.update!(checkout_url: data["checkoutUrl"])
      Result.new(ok: true, checkout_url: data["checkoutUrl"])
    else
      failure("Không tạo được liên kết thanh toán. Vui lòng thử lại.")
    end
  end

  # PayOS giới hạn mô tả 25 ký tự.
  def description
    "#{@order.code}".first(25)
  end

  # Webhook về trễ thì màn hình "kết quả" tự hỏi lại PayOS — phụ huynh không
  # phải ngồi đợi trạng thái tự nhảy.
  def self.confirm!(order)
    return true if order.paid?
    info = PayosService.new.get_payment_info(order.payos_order_code)
    return false if info.nil?

    case info["status"]
    when "PAID"      then order.apply_payment!(method: "payos", gateway_response: info)
    when "CANCELLED" then order.update!(checkout_url: nil)
    end
    order.reload.paid?
  end

  private

  def failure(message) = Result.new(ok: false, error: message)
end
