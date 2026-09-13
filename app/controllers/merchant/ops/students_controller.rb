module Merchant
  module Ops
    # Danh sách học viên của hồ đang trực. Wizard đăng ký học viên mới (FR-204)
    # gắn với slot lịch nên nằm ở P2 cùng bảng master data.
    class StudentsController < BaseController
      before_action :set_student, only: [:show, :edit, :update]

      def index
        @q = params[:q].to_s.strip
        scope = pool_scope(Student.all).includes(:household, :face_profile, :pool)
        scope = scope.where("students.name ILIKE :q", q: "%#{@q}%") if @q.present?
        @kind = %w[center renter].include?(params[:kind]) ? params[:kind] : nil
        scope = scope.where(kind: @kind) if @kind
        @students = scope.order(:name).to_a
        @counts = pool_scope(Student.all).group(:kind).count
      end

      def show
        @household = @student.household
        @siblings = @household.students.where.not(id: @student.id).to_a
      end

      def edit; end

      def update
        before = @student.attributes.dup
        if @student.update(student_params)
          audit!("update", @student, summary: "Sửa hồ sơ học viên #{@student.name}",
                 before: before, after: @student.attributes)
          redirect_to merchant_ops_student_path(@student), notice: "Đã lưu."
        else
          render :edit, status: :unprocessable_entity
        end
      end

      private

      def nav_key = :students
      def set_student = @student = pool_scope(Student.all).find(params[:id])

      def student_params
        params.require(:student).permit(:name, :birthdate, :gender, :health_notes, :source, :status)
      end
    end
  end
end
