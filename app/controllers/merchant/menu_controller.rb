module Merchant
  # Menu đầy đủ cho màn hình hẹp. Ở ≤900px sidebar bị ẩn và thanh tab dưới đáy
  # chỉ còn 5 ô, nên 10 mục còn lại (đơn hàng, chấm công, chat, vé lẻ, thi tốt
  # nghiệp, học bù…) không có đường nào tới được từ điện thoại.
  #
  # Trang này render lại đúng partial sidebar chứ không chép danh sách link ra
  # chỗ thứ hai — thêm mục mới vào sidebar là menu có ngay, không sợ lệch.
  class MenuController < BaseController
    def show
      @area = params[:area] == "bod" ? :bod : :ops
    end

    private

    def nav_key = :menu
  end
end
