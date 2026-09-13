module Webhooks
  # PayOS gọi về server-to-server. Không CSRF, không auth.
  #
  # LUÔN trả 200 để PayOS chấp nhận URL webhook (ping đăng ký của họ không có
  # chữ ký). Chỉ HÀNH ĐỘNG khi payload verify được chữ ký, nên trả 200 cho ping
  # là an toàn.
  #
  # Một mã đơn có thể là hoá đơn thuê bao nền tảng (Invoice, prefix 73_0) hoặc
  # đơn khoá học của trung tâm (Order, prefix 73_1) — tra cả hai.
  class PayosController < ActionController::Base
    skip_forgery_protection

    def receive
      payload = JSON.parse(request.body.read) rescue {}
      if payload.present? && PayosService.new.verify_webhook(payload)
        process_payment(payload)
      else
        Rails.logger.info("[PayOS webhook] ping / payload chưa verify — trả 200")
      end
      render json: { success: true }
    rescue => e
      Rails.logger.error("[PayOS webhook] #{e.class}: #{e.message}")
      render json: { success: true }
    end

    private

    def process_payment(payload)
      order_code = payload.dig("data", "orderCode").to_i
      return if order_code.zero?

      record = ActsAsTenant.without_tenant do
        Order.find_by(payos_order_code: order_code) || Invoice.find_by(payos_order_code: order_code)
      end
      return Rails.logger.warn("[PayOS webhook] không tìm thấy đơn #{order_code}") if record.nil?

      ActsAsTenant.with_tenant(record.workspace) do
        case payload["code"]
        when "00"
          # apply_payment! khoá dòng và kiểm tra lại trạng thái, nên webhook về
          # hai lần cũng chỉ ghi nhận một lần (chống ghi nhận trùng).
          if record.is_a?(Order)
            record.apply_payment!(method: "payos", gateway_response: payload)
            notify_paid(record)
          else
            record.apply_payment!(gateway_response: payload)
          end
        when "01", "02"
          record.mark_failed!(gateway_response: payload)
        end
      end
    end

    # Thanh toán xong phải báo CẢ HAI phía: phụ huynh để yên tâm, và admin của hồ
    # để biết tiền đã về mà không phải ngồi F5 màn hình đơn hàng.
    def notify_paid(order)
      notify_guardians(order)
      notify_staff(order)
    end

    def notify_guardians(order)
      guardians = order.household&.guardians.to_a
      return if guardians.empty?
      title = "Đã nhận thanh toán #{money(order.total)}"
      body  = "Đơn #{order.code} đã được ghi nhận. Cảm ơn quý phụ huynh."
      guardians.each do |g|
        Notification.create!(workspace: order.workspace, recipient: g, kind: "invoice",
                             title: title, body: body, subject: order, deep_link: "/invoices")
      end
      PushJob.perform_later(order.workspace_id, "Guardian", guardians.map(&:id), title, body, "/invoices")
    end

    def notify_staff(order)
      staff_ids = User.where(id: PoolAssignment.where(pool_id: order.pool_id).select(:user_id))
                      .where(id: Membership.where(workspace_id: order.workspace_id,
                                                  role: %w[bod admin sale]).select(:user_id))
                      .pluck(:id)
      # Sale tạo đơn thì luôn được báo, kể cả khi không còn được gán hồ đó nữa.
      staff_ids |= [order.sale_id].compact
      return if staff_ids.empty?

      who = order.student&.name || order.household&.name || "khách lẻ"
      title = "Đã thu #{money(order.total)} · #{order.code}"
      body  = "#{who} vừa thanh toán qua PayOS."
      staff_ids.each do |uid|
        Notification.create!(workspace: order.workspace, recipient_type: "User", recipient_id: uid,
                             kind: "invoice", title: title, body: body, subject: order,
                             deep_link: "/merchant/ops/orders/#{order.id}")
      end
      PushJob.perform_later(order.workspace_id, "User", staff_ids, title, body,
                            "/merchant/ops/orders/#{order.id}")
    end

    def money(amount) = "#{ActiveSupport::NumberHelper.number_to_delimited(amount.to_i)}đ"
  end
end
