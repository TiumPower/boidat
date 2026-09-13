module Admin
  class PlansController < BaseController
    def index
      Plan.seed_defaults! if Plan.count.zero?
      @plans = Plan.ordered
    end

    def update
      plan = Plan.find(params[:id])
      if plan.update(plan_params)
        redirect_to admin_plans_path, notice: "Đã lưu gói #{plan.name}."
      else
        redirect_to admin_plans_path, alert: plan.errors.full_messages.to_sentence
      end
    end

    private

    def plan_params
      params.require(:plan).permit(:name, :price, :position, :max_pools, :max_students, :max_teachers,
                                   :allow_custom_domain, :allow_face_recognition,
                                   :allow_auto_scheduler, :allow_chat)
    end

    def nav_key = :plans
  end
end
