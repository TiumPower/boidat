module Merchant
  module Bod
    # Ngày nghỉ lễ / bảo trì của một hồ — chặn sinh buổi học và xếp lịch tự động.
    class HolidaysController < BaseController
      before_action :set_pool

      def create
        holiday = @pool.holidays.new(workspace: current_workspace,
                                     date: params[:date], reason: params[:reason])
        if holiday.save
          audit!("create", holiday, summary: "Thêm ngày nghỉ #{holiday.date} cho #{@pool.name}")
          redirect_to merchant_bod_pool_path(@pool), notice: "Đã thêm ngày nghỉ."
        else
          redirect_to merchant_bod_pool_path(@pool), alert: holiday.errors.full_messages.to_sentence
        end
      end

      def destroy
        holiday = @pool.holidays.find(params[:id])
        audit!("destroy", holiday, summary: "Xoá ngày nghỉ #{holiday.date}")
        holiday.destroy
        redirect_to merchant_bod_pool_path(@pool), notice: "Đã xoá ngày nghỉ."
      end

      private

      def nav_key = :pools
      def set_pool = @pool = Pool.find(params[:pool_id])
    end
  end
end
