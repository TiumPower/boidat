module Merchant
  module Ops
    # Bản cam kết điện tử (FR-207). Sale mở màn hình này ngay sau khi tạo lớp:
    # PDF điền sẵn thông tin, hai bên ký trên màn hình, file lưu gắn với lớp học.
    class ContractsController < BaseController
      def new
        @enrollment = Enrollment.where(pool_id: current_pool.id).find(params[:enrollment_id])
        @contract = @enrollment.contract || build_contract(@enrollment)
      end

      def create
        enrollment = Enrollment.where(pool_id: current_pool.id).find(params[:enrollment_id])
        contract = enrollment.contract || build_contract(enrollment)
        contract.sign!(
          guardian_name: params[:guardian_name].presence || enrollment.student.household.owner&.name,
          guardian_signature: signature_blob(params[:guardian_signature], "guardian"),
          center_signature: signature_blob(params[:center_signature], "center"),
          actor: current_user, request: request
        )
        audit!("create", contract, summary: "Ký cam kết #{contract.number} cho #{enrollment.student.name}")
        redirect_to merchant_ops_contract_path(contract), notice: "Đã lưu bản cam kết đã ký."
      end

      def show
        @contract = Contract.where(pool_id: current_pool.id).find(params[:id])
      end

      def download
        contract = Contract.where(pool_id: current_pool.id).find(params[:id])
        return redirect_to(merchant_ops_contract_path(contract), alert: "Chưa có file PDF.") unless contract.pdf.attached?

        # Xem file cam kết là truy cập dữ liệu nhạy cảm → ghi nhật ký (OQ-19).
        audit!("read_sensitive", contract, summary: "Tải cam kết #{contract.number}")
        send_data contract.pdf.download, filename: "#{contract.number}.pdf",
                  type: "application/pdf", disposition: "inline"
      end

      private

      def nav_key = :students

      def build_contract(enrollment)
        Contract.new(workspace: current_workspace, pool: current_pool, enrollment: enrollment,
                     household: enrollment.student.household,
                     guardian_name: enrollment.student.household.owner&.name)
      end

      # Chữ ký vẽ trên canvas gửi lên dạng data URL.
      def signature_blob(data_url, kind)
        return nil if data_url.blank? || !data_url.start_with?("data:image")
        encoded = data_url.split(",", 2).last
        {
          io: StringIO.new(Base64.decode64(encoded)),
          filename: "#{kind}-signature.png",
          content_type: "image/png"
        }
      rescue StandardError
        nil
      end
    end
  end
end
