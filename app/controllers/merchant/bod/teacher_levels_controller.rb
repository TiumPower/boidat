module Merchant
  module Bod
    # Cấu hình cấp độ giáo viên (FR-216). Số học viên tối đa/tiết là ràng buộc
    # cứng của bộ xếp lịch; đơn giá/công là đầu vào của bảng lương (OQ-18).
    class TeacherLevelsController < BaseController
      before_action :set_level, only: [:edit, :update, :destroy]

      def index
        @levels = TeacherLevel.ordered.to_a
        @counts = ::Teacher.group(:teacher_level_id).count
        @level  = TeacherLevel.new(workspace: current_workspace, position: @levels.size,
                                   max_students_per_slot: 2)
      end

      def create
        @level = TeacherLevel.new(level_params.merge(workspace: current_workspace))
        if @level.save
          audit!("create", @level, summary: "Tạo #{@level.name}")
          redirect_to merchant_bod_teacher_levels_path, notice: "Đã tạo #{@level.name}."
        else
          @levels = TeacherLevel.ordered.to_a
          @counts = ::Teacher.group(:teacher_level_id).count
          render :index, status: :unprocessable_entity
        end
      end

      def edit; end

      def update
        before = @level.attributes.dup
        if @level.update(level_params)
          audit!("update", @level, summary: "Sửa #{@level.name}", before: before, after: @level.attributes)
          redirect_to merchant_bod_teacher_levels_path, notice: "Đã lưu #{@level.name}."
        else
          render :edit, status: :unprocessable_entity
        end
      end

      def destroy
        if ::Teacher.where(teacher_level: @level).exists?
          redirect_to merchant_bod_teacher_levels_path,
                      alert: "Không xoá được: còn giáo viên đang xếp ở cấp độ này."
        else
          audit!("destroy", @level, summary: "Xoá #{@level.name}")
          @level.destroy
          redirect_to merchant_bod_teacher_levels_path, notice: "Đã xoá cấp độ."
        end
      end

      private

      def nav_key = :teachers
      def set_level = @level = TeacherLevel.find(params[:id])

      def level_params
        params.require(:teacher_level).permit(:name, :position, :max_students_per_slot,
                                              :pay_rate_per_credit, :description)
      end
    end
  end
end
