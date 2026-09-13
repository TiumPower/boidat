module Desk
  class PushController < BaseController
    skip_before_action :verify_authenticity_token, only: [:subscribe], raise: false

    def subscribe
      keys = (params[:keys] || {}).permit(:p256dh, :auth)
      return render(json: { ok: false }, status: :unprocessable_entity) if params[:endpoint].blank?
      PushSubscription.store_for_user!(user: current_user, workspace: current_workspace,
                                       endpoint: params[:endpoint], p256dh: keys[:p256dh], auth: keys[:auth])
      render json: { ok: true }
    end
  end
end
