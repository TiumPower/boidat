module Customer
  # Phụ huynh xem và ký bản cam kết ngay trên PWA (FR-207).
  class ContractsController < BaseController
    before_action :require_guardian!
    before_action :set_contract

    def show; end

    def sign
      @contract.sign!(guardian_name: params[:guardian_name].presence || current_guardian.name,
                      guardian_signature: signature_blob(params[:guardian_signature]),
                      request: request)
      redirect_to member_contract_path(@contract), notice: "Đã ký cam kết. Cảm ơn quý phụ huynh."
    end

    private

    def set_contract
      @contract = Contract.where(household_id: current_household.id).find(params[:id])
    end

    def signature_blob(data_url)
      return nil if data_url.blank? || !data_url.start_with?("data:image")
      { io: StringIO.new(Base64.decode64(data_url.split(",", 2).last)),
        filename: "guardian-signature.png", content_type: "image/png" }
    rescue StandardError
      nil
    end
  end
end
