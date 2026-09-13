module Admin
  class BillingController < BaseController
    def show
      ActsAsTenant.without_tenant do
        @invoices = Invoice.order(created_at: :desc).limit(100).includes(:workspace).to_a
        @paid_this_month = Invoice.where(status: "paid", paid_at: Time.current.all_month).sum(:amount)
        @pending_total   = Invoice.where(status: "pending").sum(:amount)
      end
      @mrr = Workspace.where(status: "active").sum(&:monthly_price)
    end

    private

    def nav_key = :billing
  end
end
