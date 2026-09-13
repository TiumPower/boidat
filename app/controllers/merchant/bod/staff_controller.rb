module Merchant
  module Bod
    # Quản lý tài khoản nhân sự (FR-113, FR-218): Admin nhập email và TỰ ĐẶT mật
    # khẩu, gửi cho người dùng qua kênh riêng — hệ thống không gửi email kích hoạt.
    # Danh sách vai trò chọn được KHÔNG có BOD (chỉ Super Admin nền tảng tạo BOD).
    class StaffController < BaseController
      ASSIGNABLE_ROLES = (Membership::ROLES - ["bod"]).freeze

      before_action :set_membership, only: [:edit, :update, :destroy, :reset_password]

      def index
        @memberships = current_workspace.memberships.includes(:user).order(:role).to_a
        @assignments = PoolAssignment.group(:user_id).count
        @pool_names  = Pool.ordered.index_by(&:id)
        @by_user     = PoolAssignment.includes(:pool).group_by(&:user_id)
      end

      def new
        @user = User.new
        @role = "sale"
        @pool_ids = []
      end

      def create
        @role     = ASSIGNABLE_ROLES.include?(params[:role]) ? params[:role] : "sale"
        @pool_ids = Array(params[:pool_ids]).map(&:to_i)
        @password = params.dig(:user, :password).presence || SecureRandom.alphanumeric(10)
        @user = User.new(user_params.merge(password: @password, locale: "vi"))

        if User.exists?(email: @user.email)
          @user.errors.add(:email, "đã có tài khoản trong hệ thống")
          return render(:new, status: :unprocessable_entity)
        end

        ActiveRecord::Base.transaction do
          @user.save!
          Membership.create!(user: @user, workspace: current_workspace, role: @role)
          assign_pools(@user, @pool_ids)
          create_teacher_profile(@user) if @role == "teacher"
        end
        audit!("create", @user, summary: "Tạo tài khoản #{@role} cho #{@user.email}")
        redirect_to merchant_bod_staff_index_path,
                    notice: "Đã tạo tài khoản #{@user.email} · mật khẩu: #{@password} (gửi riêng cho nhân sự)."
      rescue ActiveRecord::RecordInvalid
        render :new, status: :unprocessable_entity
      end

      def edit
        @user = @membership.user
        @role = @membership.role
        @pool_ids = PoolAssignment.where(user_id: @user.id).pluck(:pool_id)
      end

      def update
        @user = @membership.user
        @role = ASSIGNABLE_ROLES.include?(params[:role]) ? params[:role] : @membership.role
        @pool_ids = Array(params[:pool_ids]).map(&:to_i)
        before = { role: @membership.role, pools: PoolAssignment.where(user_id: @user.id).pluck(:pool_id) }

        ActiveRecord::Base.transaction do
          @user.update!(user_params.except(:password))
          @membership.update!(role: @role, status: params[:status].presence || @membership.status)
          assign_pools(@user, @pool_ids)
          create_teacher_profile(@user) if @role == "teacher"
        end
        audit!("update", @user, summary: "Sửa tài khoản #{@user.email}",
               before: before, after: { role: @role, pools: @pool_ids })
        redirect_to merchant_bod_staff_index_path, notice: "Đã cập nhật #{@user.name}."
      rescue ActiveRecord::RecordInvalid
        render :edit, status: :unprocessable_entity
      end

      # Đặt lại mật khẩu hộ nhân sự (FR-115) — trả mật khẩu mới ngay trên màn hình
      # để admin đọc cho người đó, đúng như cách trung tâm đang làm.
      def reset_password
        password = SecureRandom.alphanumeric(10)
        @membership.user.update!(password: password)
        audit!("update", @membership.user, summary: "Đặt lại mật khẩu cho #{@membership.user.email}")
        redirect_to merchant_bod_staff_index_path,
                    notice: "Mật khẩu mới của #{@membership.user.name}: #{password}"
      end

      # Không xoá tài khoản: gỡ khỏi trung tâm và khoá lại, để nhật ký thao tác và
      # dữ liệu người đó đã tạo vẫn truy vết được.
      def destroy
        @membership.update!(status: "suspended")
        PoolAssignment.where(user_id: @membership.user_id).destroy_all
        audit!("update", @membership.user, summary: "Khoá tài khoản #{@membership.user.email}")
        redirect_to merchant_bod_staff_index_path, notice: "Đã khoá tài khoản."
      end

      private

      def nav_key = :staff

      def set_membership
        @membership = current_workspace.memberships.find(params[:id])
      end

      def user_params
        params.require(:user).permit(:name, :email, :phone, :title)
      end

      def assign_pools(user, pool_ids)
        allowed = Pool.where(id: pool_ids).pluck(:id)
        current = PoolAssignment.where(user_id: user.id).pluck(:pool_id)
        (allowed - current).each { |pid| PoolAssignment.create!(workspace: current_workspace, pool_id: pid, user: user) }
        PoolAssignment.where(user_id: user.id).where.not(pool_id: allowed).destroy_all
      end

      def create_teacher_profile(user)
        teacher = Teacher.find_or_initialize_by(workspace: current_workspace, user: user)
        teacher.kind ||= "staff"
        teacher.status ||= "active"
        teacher.save!
        PoolAssignment.where(user_id: user.id).pluck(:pool_id).each do |pid|
          TeacherPool.find_or_create_by!(workspace: current_workspace, teacher: teacher, pool_id: pid)
        end
      end
    end
  end
end
