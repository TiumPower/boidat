module Merchant
  module Bod
    # Khoá học + giáo án từng buổi (FR-212). Giáo án ở đây là bản mặc định; giáo
    # viên sửa được cho riêng buổi mình dạy mà không đụng bản gốc.
    class CoursesController < BaseController
      before_action :set_course, only: [:show, :edit, :update, :destroy, :generate_plan]

      def index
        @courses = Course.ordered.includes(:course_sessions, :packages).to_a
      end

      def show
        @sessions = @course.course_sessions.ordered.to_a
        @packages = @course.packages.ordered.to_a
      end

      def new
        @course = Course.new(workspace: current_workspace, audience: "child", status: "active",
                             class_types: [1, 2, 3, 4])
      end

      def create
        @course = Course.new(course_params.merge(workspace: current_workspace))
        if @course.save
          @course.ensure_session_plan!
          audit!("create", @course, summary: "Tạo khoá #{@course.name}")
          redirect_to merchant_bod_course_path(@course), notice: "Đã tạo khoá #{@course.name}."
        else
          render :new, status: :unprocessable_entity
        end
      end

      def edit; end

      def update
        before = @course.attributes.dup
        if @course.update(course_params)
          apply_sessions if params[:sessions].present?
          audit!("update", @course, summary: "Sửa khoá #{@course.name}", before: before, after: @course.attributes)
          redirect_to merchant_bod_course_path(@course), notice: "Đã lưu."
        else
          render :edit, status: :unprocessable_entity
        end
      end

      # Sinh đủ khung giáo án theo số buổi của khoá, đánh dấu sẵn buổi thi.
      def generate_plan
        @course.ensure_session_plan!
        redirect_to merchant_bod_course_path(@course), notice: "Đã tạo khung giáo án #{@course.total_sessions} buổi."
      end

      def destroy
        if @course.packages.exists?
          redirect_to merchant_bod_courses_path, alert: "Không xoá được: còn gói sản phẩm gắn với khoá này."
        else
          audit!("destroy", @course, summary: "Xoá khoá #{@course.name}")
          @course.destroy
          redirect_to merchant_bod_courses_path, notice: "Đã xoá khoá học."
        end
      end

      private

      def nav_key = :courses
      def set_course = @course = Course.find(params[:id])

      def course_params
        permitted = params.require(:course).permit(:name, :code, :description, :audience, :status,
                                                   :position, :sessions_count, :graduation_at_session,
                                                   :exam_session_index, :validity_days, class_types: [])
        permitted[:class_types] = Array(permitted[:class_types]).map(&:to_i).select(&:positive?) if permitted.key?(:class_types)
        permitted
      end

      def apply_sessions
        params[:sessions].each do |pos, attrs|
          row = CourseSession.find_or_initialize_by(workspace: current_workspace, course: @course, position: pos.to_i)
          row.assign_attributes(title: attrs[:title].presence || "Buổi #{pos}",
                                content: attrs[:content], goal: attrs[:goal],
                                exam: attrs[:exam] == "1")
          row.save
        end
      end
    end
  end
end
