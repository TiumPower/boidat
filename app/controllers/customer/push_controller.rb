module Customer
  class PushController < BaseController
    skip_before_action :verify_authenticity_token, only: [:subscribe, :unsubscribe], raise: false
    before_action :require_guardian!

    def subscribe
      keys = (params[:keys] || {}).permit(:p256dh, :auth)
      return render(json: { ok: false }, status: :unprocessable_entity) if params[:endpoint].blank?
      PushSubscription.store_for_guardian!(guardian: current_guardian, endpoint: params[:endpoint],
                                           p256dh: keys[:p256dh], auth: keys[:auth])
      render json: { ok: true }
    end

    def unsubscribe
      PushSubscription.where(guardian_id: current_guardian.id, endpoint: params[:endpoint]).destroy_all if params[:endpoint].present?
      render json: { ok: true }
    end
  end
end
