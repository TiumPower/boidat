module Merchant
  module Ops
    # Sale/Admin xem hồ sơ giáo viên của hồ đang trực (chỉ đọc — sửa hồ sơ là
    # quyền của BOD). Tab chấm công và đơn xin nghỉ nối vào ở P3/P6.
    class TeachersController < BaseController
      def index
        @teachers = ::Teacher.in_pool(current_pool).includes(:user, :teacher_level).order(:kind).to_a
      end

      def show
        @teacher = ::Teacher.in_pool(current_pool).find(params[:id])
      end

      private

      def nav_key = :teachers
    end
  end
end
