module Admin
  class DashboardController < BaseController
    def show
      @workspaces = Workspace.order(created_at: :desc).limit(20).to_a
      @counts = {
        workspaces: Workspace.count,
        active:     Workspace.where(status: "active").count,
        trial:      Workspace.where(status: "trial").count,
        pools:      ActsAsTenant.without_tenant { Pool.count },
        students:   ActsAsTenant.without_tenant { Student.where(status: "active").count },
        teachers:   ActsAsTenant.without_tenant { Teacher.where(status: "active").count }
      }
      @mrr = Workspace.where(status: "active").sum(&:monthly_price)
      @unpaid = Invoice.unscoped.where(status: "pending").order(:period_start).limit(10).to_a
    end

    private

    def nav_key = :dashboard
  end
end
