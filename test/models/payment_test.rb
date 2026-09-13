require "test_helper"

# Thanh toán: chống ghi nhận trùng là yêu cầu rõ trong FR-223 bước 6.
class PaymentTest < ActiveSupport::TestCase
  setup do
    @c = build_center!
    @ws = @c.workspace
    @order = with_tenant(@ws) do
      Order.create!(workspace: @ws, pool: @c.pools.first, household: @c.household,
                    student: @c.student, amount: 4_800_000, status: "unpaid")
    end
  end

  test "mã đơn PayOS dùng tiền tố riêng, không đụng Invoice của nền tảng" do
    with_tenant(@ws) do
      @order.reassign_payos_code!
      assert @order.payos_order_code >= 73_100_000_000, "đơn khoá học dùng dải 73_1"

      invoice = Invoice.create!(workspace: @ws, plan: "pro", amount: 100,
                                period_start: Date.current, period_end: Date.current.end_of_month)
      assert invoice.payos_order_code < 73_100_000_000, "thuê bao nền tảng dùng dải 73_0"
    end
  end

  test "webhook về hai lần chỉ ghi nhận một lần" do
    with_tenant(@ws) do
      assert @order.apply_payment!(method: "payos")
      refute @order.apply_payment!(method: "payos"), "lần thứ hai phải bị bỏ qua"
      assert_equal 1, @order.payments.count
      assert_equal 4_800_000, @order.payments.sum(:amount)
    end
  end

  test "thu tiền mặt ghi nhận người thực hiện" do
    with_tenant(@ws) do
      @order.apply_payment!(method: "cash", recorded_by: @c.users[:sale])
      payment = @order.payments.first
      assert_equal "cash", payment.method
      assert_equal @c.users[:sale].id, payment.recorded_by_id
    end
  end

  test "mở lại checkout sinh mã đơn mới để link cũ không chặn" do
    with_tenant(@ws) do
      @order.reassign_payos_code!
      first = @order.payos_order_code
      @order.update!(checkout_url: "https://pay.payos.vn/abc")
      @order.reassign_payos_code!
      refute_equal first, @order.payos_order_code
      assert_nil @order.checkout_url
    end
  end

  test "doanh thu cho thuê tách khỏi doanh thu khoá học (OQ-26)" do
    with_tenant(@ws) do
      @order.apply_payment!
      rental = Order.create!(workspace: @ws, pool: @c.pools.first, amount: 12_000_000, kind: "rental")
      rental.apply_payment!(method: "transfer")

      assert_equal 4_800_000, Order.course_revenue.sum(:amount)
      assert_equal 12_000_000, Order.rental_revenue.sum(:amount)
      assert @ws.rental_revenue_separate?
    end
  end
end
