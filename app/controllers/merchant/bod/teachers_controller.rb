module Merchant
  module Bod
    # Hồ sơ giáo viên (FR-209): level, hồ được gán, mô tả năng lực hiển thị cho
    # phụ huynh, và phân loại thuộc trung tâm / thuê hồ (OQ-12 — hai mô hình
    # kinh doanh khác nhau, không phải một checkbox).
    class TeachersController < BaseController
      before_action :set_teacher, only: [:show, :edit, :update]

      def index
        @kind = %w[staff renter].include?(params[:kind]) ? params[:kind] : nil
        scope = ::Teacher.includes(:user, :teacher_level, :pools).order(:kind)
        scope = scope.where(kind: @kind) if @kind
        @teachers = scope.to_a
        @counts = ::Teacher.group(:kind).count
        @levels = TeacherLevel.ordered.to_a
      end

      def show
        @pool_ids = @teacher.pools.pluck(:id)
      end

      def new
        @teacher = ::Teacher.new(workspace: current_workspace, kind: "staff", status: "active")
        @user = User.new
        @pool_ids = []
      end

      # Tạo giáo viên = tạo luôn tài khoản đăng nhập PWA cho họ.
      def create
        @pool_ids = Array(params[:pool_ids]).map(&:to_i)
        @password = params.dig(:user, :password).presence || SecureRandom.alphanumeric(10)
        @user = User.new(user_params.merge(password: @password, locale: "vi"))
        @teacher = ::Teacher.new(teacher_params.merge(workspace: current_workspace))

        if User.exists?(email: @user.email)
          @user.errors.add(:email, "đã có tài khoản trong hệ thống")
          return render(:new, status: :unprocessable_entity)
        end

        ActiveRecord::Base.transaction do
          @user.save!
          Membership.create!(user: @user, workspace: current_workspace, role: "teacher")
          @teacher.user = @user
          @teacher.save!
          sync_pools(@teacher, @pool_ids)
        end
        audit!("create", @teacher, summary: "Tạo giáo viên #{@user.name}")
        redirect_to merchant_bod_teacher_path(@teacher),
                    notice: "Đã tạo giáo viên #{@user.name} · mật khẩu: #{@password}"
      rescue ActiveRecord::RecordInvalid
        render :new, status: :unprocessable_entity
      end

      def edit
        @user = @teacher.user
        @pool_ids = @teacher.pools.pluck(:id)
      end

      def update
        @user = @teacher.user
        @pool_ids = Array(params[:pool_ids]).map(&:to_i)
        before = @teacher.attributes.dup
        ActiveRecord::Base.transaction do
          @user.update!(user_params.except(:password))
          @teacher.update!(teacher_params)
          sync_pools(@teacher, @pool_ids)
        end
        audit!("update", @teacher, summary: "Sửa giáo viên #{@user.name}",
               before: before, after: @teacher.attributes)
        redirect_to merchant_bod_teacher_path(@teacher), notice: "Đã lưu hồ sơ."
      rescue ActiveRecord::RecordInvalid
        render :edit, status: :unprocessable_entity
      end

      private

      def nav_key = :teachers

      def set_teacher = @teacher = ::Teacher.find(params[:id])

      def user_params  = params.require(:user).permit(:name, :email, :phone, :title)

      def teacher_params
        params.require(:teacher).permit(:teacher_level_id, :kind, :status, :specialty,
                                        :years_experience, :bio, :org_name)
      end

      # Giáo viên dạy hồ nào thì cũng phải được gán quyền truy cập hồ đó, nếu
      # không PWA của họ sẽ trống trơn.
      def sync_pools(teacher, pool_ids)
        allowed = Pool.where(id: pool_ids).pluck(:id)
        current = teacher.pools.pluck(:id)
        (allowed - current).each { |pid| TeacherPool.create!(workspace: current_workspace, teacher: teacher, pool_id: pid) }
        teacher.teacher_pools.where.not(pool_id: allowed).destroy_all

        (allowed - PoolAssignment.where(user_id: teacher.user_id).pluck(:pool_id)).each do |pid|
          PoolAssignment.create!(workspace: current_workspace, pool_id: pid, user_id: teacher.user_id)
        end
        PoolAssignment.where(user_id: teacher.user_id).where.not(pool_id: allowed).destroy_all
      end
    end
  end
end
