module Merchant
  module Ops
    # Admin duyệt đơn xin nghỉ của giáo viên (FR-211) và theo dõi ai đã / chưa
    # xác nhận phương án học bù (OQ-16 — vì bỏ Zalo ZNS/SMS nên màn hình theo
    # dõi này là bắt buộc, không phải tuỳ chọn).
    class LeaveRequestsController < BaseController
      before_action :require_approver!, only: [:approve, :reject]
      before_action :set_request, only: [:show, :approve, :reject]

      def index
        teacher_ids = ::Teacher.in_pool(current_pool).select(:id)
        @pending = LeaveRequest.pending.where(teacher_id: teacher_ids).includes(:teacher).recent.to_a
        @recent  = LeaveRequest.where(teacher_id: teacher_ids).where.not(status: "pending")
                               .includes(:teacher).recent.limit(20).to_a
        @callback_list = callback_list
      end

      def show
        @lessons = @request.lessons.includes(swim_class: { enrollments: :student }).to_a
        @students = @request.affected_students.to_a
      end

      def approve
        count = LeaveApproval.new(@request, actor: current_user).approve!(note: params[:note])
        audit!("update", @request, summary: "Duyệt đơn nghỉ của #{@request.teacher.display_name} · #{count} buổi")
        redirect_to merchant_ops_leave_requests_path,
                    notice: "Đã duyệt. #{count} buổi bị huỷ, phụ huynh đã được thông báo và cần xác nhận phương án."
      end

      def reject
        LeaveApproval.new(@request, actor: current_user).reject!(note: params[:note])
        audit!("update", @request, summary: "Từ chối đơn nghỉ của #{@request.teacher.display_name}")
        redirect_to merchant_ops_leave_requests_path, notice: "Đã từ chối đơn."
      end

      private

      def nav_key = :leaves

      def require_approver!
        return if current_membership&.can_manage_staff?
        redirect_to merchant_ops_leave_requests_path, alert: "Chỉ Admin hoặc BOD mới duyệt được đơn nghỉ."
      end

      def set_request
        @request = LeaveRequest.where(teacher_id: ::Teacher.in_pool(current_pool).select(:id))
                               .find(params[:id])
      end

      # Danh sách phụ huynh CHƯA xác nhận — admin gọi điện cho đúng nhóm này.
      def callback_list
        Notification.where(recipient_type: "Guardian", kind: "teacher_leave",
                           requires_ack: true, acknowledged_at: nil)
                    .where("created_at > ?", 14.days.ago)
                    .includes(:recipient).limit(50).to_a
      end
    end
  end
end
