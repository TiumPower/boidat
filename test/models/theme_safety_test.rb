require "test_helper"

# Màu theme do BOD tự nhập ở màn Giao diện, rồi được đổ thẳng vào một khối
# <style> dùng chung cho mọi trang của trung tâm — gồm cả các trang phụ huynh.
#
# Thoát HTML không đỡ được ở ngữ cảnh này: chuỗi `red; } * { display:none } .x {`
# không chứa ký tự nào bị thoát, nhưng nó thoát ra khỏi khai báo CSS và viết lại
# giao diện cho tất cả mọi người. Trước đây `permit(:primary, ...)` nhận chuỗi
# bất kỳ và không ai kiểm.
class ThemeSafetyTest < ActiveSupport::TestCase
  setup { @ws = create(:workspace) }

  BREAKOUTS = [
    "red; } * { display:none } .x {",
    "#fff; background-image: url(https://kẻ-xấu.example/thu-thap)",
    "}</style><script>alert(1)</script><style>{",
    "expression(alert(1))"
  ].freeze

  test "không lưu được màu thoát ra khỏi khai báo CSS" do
    BREAKOUTS.each do |payload|
      @ws.theme = @ws.theme.to_h.merge("primary" => payload)
      refute @ws.valid?, "phải chặn: #{payload.inspect}"
      assert @ws.errors[:theme].any?
    end
  end

  test "mã màu hợp lệ vẫn dùng được" do
    ["#0E7C86", "#fff", "rgb(14,124,134)", "rgba(14, 124, 134, .5)", "hsl(186, 80%, 29%)"].each do |ok|
      @ws.theme = @ws.theme.to_h.merge("primary" => ok)
      assert @ws.valid?, "phải cho qua: #{ok}"
    end
  end

  test "dữ liệu xấu lỡ nằm sẵn trong DB thì render ra giá trị mặc định" do
    @ws.update_column(:theme, @ws.theme.to_h.merge("primary" => BREAKOUTS.first))
    assert_equal Workspace::DEFAULT_THEME["primary"], @ws.reload.theme_value(:primary),
                 "chặn lúc ghi là chưa đủ — bản ghi cũ vẫn phải an toàn khi đọc"
  end

  test "bo góc chỉ nhận số hoặc số kèm px" do
    @ws.update_column(:theme, @ws.theme.to_h.merge("radius" => "16px; } * {display:none} .x{"))
    assert_equal Workspace::DEFAULT_THEME["radius"], @ws.reload.css_radius

    @ws.update_column(:theme, @ws.theme.to_h.merge("radius" => "12"))
    assert_equal "12px", @ws.reload.css_radius
  end

  test "font chỉ lấy từ danh sách có sẵn, không nhận chữ tự do" do
    @ws.theme = @ws.theme.to_h.merge("font_display" => "Comic Sans của tôi")
    refute @ws.valid?
    assert @ws.errors[:theme].any?
  end

  # Đây là lỗi nặng hơn cả CSS injection: `DEFAULT_THEME` khoá bằng chuỗi nên
  # `DEFAULT_THEME[:font_display]` luôn nil, đường lui của font_stack biến mất,
  # và view gọi `.html_safe` trên nil → NoMethodError. Một tên font lạ trong DB
  # là toàn bộ năm cổng của trung tâm đó trả 500.
  test "font lạ lỡ nằm trong DB vẫn phải render được, không làm sập cả trung tâm" do
    @ws.update_column(:theme, @ws.theme.to_h.merge("font_display" => "Comic Sans của tôi"))
    stack = @ws.reload.font_stack(:font_display)
    assert stack.present?, "font_stack trả nil thì view nổ NoMethodError trên mọi trang"
    assert_nothing_raised { stack.html_safe }
    refute_includes stack, "}", "phải tra bảng trắng chứ không trả chữ người dùng nhập"
  end
end
