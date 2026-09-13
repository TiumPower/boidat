module Merchant
  module Ops
    # Danh sách học viên chuẩn bị thi tốt nghiệp (FR-208).
    #
    # Điều kiện là số buổi đã học **bằng đúng** mốc cấu hình, không phải "từ mốc
    # đó trở lên". Vì vậy hệ thống gắn cờ `exam_eligible_at` khi học viên chạm
    # mốc và GIỮ họ trong danh sách cho tới khi có kết quả thi — nếu không,
    # admin bận một tuần là mất dấu học viên đó (OQ-07).
    class GraduationsController < BaseController
      def index
        scope = Enrollment.where(pool_id: current_pool.id)
                          .includes(:student, swim_class: [:teacher, :course])
        @eligible = scope.where.not(exam_eligible_at: nil).where(exam_result: nil).to_a
        @scheduled = scope.where.not(exam_date: nil).where(exam_result: nil).to_a
        @results = scope.where.not(exam_result: nil).order(exam_date: :desc).limit(30).to_a
        @target = current_workspace.graduation_at_session
      end

      def update
        enrollment = Enrollment.where(pool_id: current_pool.id).find(params[:id])
        attrs = params.permit(:exam_date, :exam_result).to_h.compact_blank
        enrollment.update!(attrs)
        if enrollment.exam_result == "passed"
          enrollment.student.update!(status: "graduated")
          notify_result(enrollment)
        end
        audit!("update", enrollment,
               summary: "Cập nhật thi tốt nghiệp #{enrollment.student.name} · #{enrollment.exam_result_label || enrollment.exam_date}")
        redirect_to merchant_ops_graduations_path, notice: "Đã cập nhật #{enrollment.student.name}."
      end

      private

      def nav_key = :students

      def notify_result(enrollment)
        guardians = enrollment.student.household.guardians.to_a
        return if guardians.empty?
        title = "#{enrollment.student.name} đã tốt nghiệp 🏅"
        body = "Chúc mừng! #{enrollment.student.short_name} đã hoàn thành khoá " \
               "#{enrollment.swim_class.course&.name}."
        guardians.each do |g|
          Notification.create!(workspace: current_workspace, recipient: g, kind: "exam",
                               title: title, body: body, subject: enrollment, deep_link: "/")
        end
        PushJob.perform_later(current_workspace.id, "Guardian", guardians.map(&:id), title, body, "/")
      end
    end
  end
end
