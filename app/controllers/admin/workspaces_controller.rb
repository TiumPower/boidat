module Admin
  class WorkspacesController < BaseController
    before_action :set_workspace, only: [:show, :update, :approve, :suspend, :reactivate, :destroy, :impersonate]

    def index
      ActsAsTenant.without_tenant do
        scope = Workspace.order(created_at: :desc)
        @status = params[:status] if Workspace::STATUSES.include?(params[:status])
        scope = scope.where(status: @status) if @status
        @counts = Workspace.group(:status).count
        @workspaces = scope.to_a
        @pool_counts    = Pool.unscoped.group(:workspace_id).count
        @student_counts = Student.unscoped.where(status: "active").group(:workspace_id).count
        @teacher_counts = Teacher.unscoped.where(status: "active").group(:workspace_id).count
      end
    end

    def new
      @workspace = Workspace.new(status: "active", plan: "starter")
    end

    # Tạo trung tâm mới + tài khoản BOD đầu tiên (FR-001 — seed sẵn một BOD và
    # một Admin, người này đi tạo các tài khoản còn lại).
    def create
      @workspace = Workspace.new(create_params)
      @workspace.status ||= "active"
      @workspace.plan   ||= "starter"
      @email      = params[:owner_email].to_s.downcase.strip
      @owner_name = params[:owner_name].presence || "BOD #{@workspace.name}"
      @password   = params[:owner_password].presence || SecureRandom.alphanumeric(10)

      return render(:new, status: :unprocessable_entity) unless valid_admin_create?

      ActiveRecord::Base.transaction do
        @workspace.save!
        owner = User.find_or_initialize_by(email: @email)
        if owner.new_record?
          owner.assign_attributes(name: @owner_name, password: @password, locale: "vi")
          owner.save!
        end
        ActsAsTenant.with_tenant(@workspace) { @workspace.memberships.create!(user: owner, role: "bod") }
        WorkspaceBootstrap.call(@workspace)
      end
      redirect_to admin_workspace_path(@workspace),
                  notice: "Đã tạo trung tâm #{@workspace.name}. BOD đăng nhập: #{@email} / #{@password}"
    rescue ActiveRecord::RecordInvalid
      render :new, status: :unprocessable_entity
    end

    def show
      load_stats
    end

    def update
      if @workspace.update(update_params)
        redirect_to admin_workspace_path(@workspace), notice: "Đã cập nhật trung tâm."
      else
        load_stats
        render :show, status: :unprocessable_entity
      end
    end

    def approve    = transition("active",    "Đã duyệt trung tâm.")
    def suspend    = transition("suspended", "Đã tạm ngưng trung tâm.")
    def reactivate = transition("active",    "Đã kích hoạt lại trung tâm.")

    # Mở back office DƯỚI DANH NGHĨA BOD của trung tâm (hỗ trợ kỹ thuật).
    def impersonate
      owner = @workspace.owner
      if owner.nil?
        return redirect_back(fallback_location: admin_workspace_path(@workspace),
                             alert: "Trung tâm chưa có tài khoản BOD.")
      end
      sign_in(:user, owner)
      session[:workspace_id] = @workspace.id
      session[:impersonator_admin_id] = current_admin_user.id
      redirect_to merchant_url_for(@workspace, "/merchant"), allow_other_host: true
    end

    def destroy
      name = @workspace.name
      WorkspacePurge.call(@workspace)
      redirect_to admin_workspaces_path, notice: "Đã xoá vĩnh viễn trung tâm “#{name}”."
    end

    private

    def nav_key = :workspaces

    def set_workspace
      ActsAsTenant.without_tenant { @workspace = Workspace.friendly.find(params[:id]) }
    end

    def load_stats
      ActsAsTenant.with_tenant(@workspace) do
        @pools_count    = Pool.count
        @students_count = Student.count
        @teachers_count = Teacher.count
        @staff_count    = @workspace.memberships.count
        @pools          = Pool.ordered.to_a
      end
    end

    def transition(status, msg)
      @workspace.update!(status: status)
      redirect_back fallback_location: admin_workspaces_path, notice: msg
    end

    def create_params
      params.require(:workspace).permit(:name, :subdomain, :status, :plan, :locale_default)
    end

    def update_params
      params.require(:workspace).permit(:name, :subdomain, :custom_domain, :status, :plan, :locale_default)
    end

    def valid_admin_create?
      ok = @workspace.valid?
      if TenantResolver::RESERVED_SUBDOMAINS.include?(@workspace.subdomain.to_s.downcase)
        @workspace.errors.add(:subdomain, "không sử dụng được (đã dành riêng)"); ok = false
      end
      if @email.blank? || !@email.include?("@")
        @workspace.errors.add(:base, "Email BOD không hợp lệ"); ok = false
      end
      ok
    end
  end
end
