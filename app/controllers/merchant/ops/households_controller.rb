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
        # Một mã cho mỗi người giám hộ: quyền của chủ hộ và người đưa đón khác
        # nhau (OQ-03), mà dùng chung một mã thì không thể biết ai đang quét.
        @qr_urls = @household.guardians.to_h do |g|
          [g.id, member_qr_login_url(qr_token: g.qr_token, host: request.host_with_port,
                                     protocol: request.protocol, workspace_slug: current_workspace.slug)]
        end
      end

      # Cấp lại QR: mã cũ mất hiệu lực ngay, người đó phải quét lại mã mới.
      def reissue_qr
        guardian = @household.guardians.find_by(id: params[:guardian_id])
        if guardian
          guardian.reissue_qr!
          audit!("update", @household, summary: "Cấp lại mã QR cho #{guardian.name} (#{@household.name})")
          notice = "Đã cấp mã QR mới cho #{guardian.name}. Mã cũ không dùng được nữa."
        else
          @household.reissue_qr!
          @household.guardians.each(&:reissue_qr!)
          audit!("update", @household, summary: "Cấp lại toàn bộ mã QR của #{@household.name}")
          notice = "Đã cấp mã QR mới cho cả nhà. Mã cũ không dùng được nữa."
        end
        redirect_to merchant_ops_household_path(@household), notice: notice
      end

      private

      def nav_key = :students
      def set_household
        @household = Household.where(id: pool_scope(Student.all).select(:household_id)).find(params[:id])
      end
    end
  end
end
