module Merchant
  module Ops
    # Hộ gia đình (FR-206) — nơi in lại mã QR đăng nhập và thu hồi/cấp lại khi
    # phụ huynh mất điện thoại (OQ-02).
    class HouseholdsController < BaseController
      before_action :set_household, only: [:show, :reissue_qr]

      def index
        @q = params[:q].to_s.strip
        # Chỉ hộ có học viên ở hồ đang trực — tránh lộ hộ của hồ khác.
        scope = Household.where(id: pool_scope(Student.all).select(:household_id))
        scope = scope.where("households.name ILIKE :q", q: "%#{@q}%") if @q.present?
        @households = scope.includes(:guardians, :students).order(:name).to_a
      end

      def show
        @students = @household.students.includes(:pool, :face_profile).to_a
        @qr_url = member_qr_login_url(@household.qr_token, host: request.host_with_port,
                                      protocol: request.protocol, workspace_slug: current_workspace.slug)
      end

      # Cấp lại QR: mã cũ mất hiệu lực ngay, mọi phiên đang mở phải quét lại.
      def reissue_qr
        @household.reissue_qr!
        audit!("update", @household, summary: "Cấp lại mã QR cho #{@household.name}")
        redirect_to merchant_ops_household_path(@household),
                    notice: "Đã cấp mã QR mới. Mã cũ không dùng được nữa."
      end

      private

      def nav_key = :students
      def set_household
        @household = Household.where(id: pool_scope(Student.all).select(:household_id)).find(params[:id])
      end
    end
  end
end
