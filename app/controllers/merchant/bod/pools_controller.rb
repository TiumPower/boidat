module Merchant
  module Bod
    # CRUD hồ bơi + lịch hoạt động + ngày nghỉ + gán nhân sự (FR-111, FR-112, FR-217).
    class PoolsController < BaseController
      before_action :set_pool, only: [:show, :edit, :update, :destroy, :assign_staff]

      def index
        @pools = Pool.ordered.includes(:operating_hours).to_a
        @student_counts = Student.where(status: "active").group(:pool_id).count
        @teacher_counts = TeacherPool.group(:pool_id).count
        @staff_counts   = PoolAssignment.group(:pool_id).count
      end

      def show
        @hours = (0..6).map do |wd|
          @pool.operating_hours.find { |h| h.weekday == wd } ||
            PoolOperatingHour.new(workspace: current_workspace, pool: @pool, weekday: wd,
                                  opens_at: "06:00", closes_at: "21:00")
        end
        @holidays = @pool.holidays.upcoming.to_a
        @assigned_ids = @pool.pool_assignments.pluck(:user_id)
        @staff = current_workspace.memberships.where.not(role: "teacher").includes(:user).to_a
      end

      def new
        @pool = Pool.new(workspace: current_workspace, status: "active")
      end

      def create
        @pool = Pool.new(pool_params.merge(workspace: current_workspace))
        if @pool.save
          seed_default_hours(@pool)
          audit!("create", @pool, summary: "Tạo hồ #{@pool.name}", after: @pool.attributes)
          redirect_to merchant_bod_pool_path(@pool), notice: "Đã tạo #{@pool.name}."
        else
          render :new, status: :unprocessable_entity
        end
      end

      def edit; end

      def update
        before = @pool.attributes.dup
        if @pool.update(pool_params)
          apply_hours if params[:hours].present?
          audit!("update", @pool, summary: "Sửa hồ #{@pool.name}", before: before, after: @pool.attributes)
          redirect_to merchant_bod_pool_path(@pool), notice: "Đã lưu #{@pool.name}."
        else
          render :edit, status: :unprocessable_entity
        end
      end

      def destroy
        if @pool.students.exists?
          redirect_to merchant_bod_pools_path,
                      alert: "Không xoá được: hồ này còn học viên. Hãy chuyển trạng thái sang “đóng cửa”."
        else
          audit!("destroy", @pool, summary: "Xoá hồ #{@pool.name}", before: @pool.attributes)
          @pool.destroy
          redirect_to merchant_bod_pools_path, notice: "Đã xoá hồ."
        end
      end

      # Gán / gỡ nhân sự cho hồ (FR-112). Gỡ gán không đụng dữ liệu lịch sử.
      def assign_staff
        wanted = Array(params[:user_ids]).map(&:to_i)
        allowed = current_workspace.memberships.where(user_id: wanted).pluck(:user_id)
        current  = @pool.pool_assignments.pluck(:user_id)

        (allowed - current).each { |uid| PoolAssignment.create!(workspace: current_workspace, pool: @pool, user_id: uid) }
        @pool.pool_assignments.where.not(user_id: allowed).destroy_all

        audit!("update", @pool, summary: "Gán nhân sự cho #{@pool.name}",
               before: { user_ids: current }, after: { user_ids: allowed })
        redirect_to merchant_bod_pool_path(@pool), notice: "Đã cập nhật danh sách nhân sự."
      end

      private

      def nav_key = :pools

      def set_pool
        @pool = Pool.find(params[:id])
      end

      def pool_params
        params.require(:pool).permit(:name, :code, :address, :phone, :status, :position)
      end

      # T2–T7 06:00–21:00, Chủ nhật nửa ngày — sửa lại được ngay ở màn chi tiết.
      def seed_default_hours(pool)
        (0..6).each do |wd|
          PoolOperatingHour.create!(workspace: current_workspace, pool: pool, weekday: wd,
                                    opens_at: "06:00", closes_at: wd.zero? ? "12:00" : "21:00")
        end
      end

      def apply_hours
        params[:hours].each do |wd, attrs|
          row = PoolOperatingHour.find_or_initialize_by(workspace: current_workspace, pool: @pool, weekday: wd.to_i)
          row.assign_attributes(opens_at: attrs[:opens_at], closes_at: attrs[:closes_at],
                                closed: attrs[:closed] == "1")
          row.save
        end
      end
    end
  end
end
