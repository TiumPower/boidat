# Bản cam kết đã ký giữa trung tâm và phụ huynh (FR-207).
#
# Lưu ý pháp lý đã trao đổi với khách (OQ-15): chữ ký vẽ tay trên màn hình KHÔNG
# phải chữ ký số theo Luật Giao dịch điện tử — nó là bằng chứng điện tử. Vì vậy
# bản ghi này lưu kèm audit trail (thời điểm, IP, thiết bị, mã băm SHA-256 của
# file PDF) để tăng giá trị chứng cứ khi có tranh chấp.
class Contract < ApplicationRecord
  acts_as_tenant(:workspace)

  STATUSES = %w[draft signed void].freeze

  belongs_to :workspace
  belongs_to :pool
  belongs_to :enrollment
  belongs_to :household
  belongs_to :signed_by, class_name: "User", optional: true

  has_one_attached :pdf
  has_one_attached :guardian_signature
  has_one_attached :center_signature

  validates :status, inclusion: { in: STATUSES }
  validates :number, presence: true, uniqueness: true

  before_validation :assign_number, on: :create

  scope :signed, -> { where(status: "signed") }

  def signed? = status == "signed"

  def student = enrollment.student

  # Ghi nhận hai chữ ký + sinh PDF + băm file. Băm phải tính TRÊN file cuối cùng,
  # sau khi đã nhúng chữ ký — băm bản nháp thì không chứng minh được gì.
  def sign!(guardian_name:, guardian_signature: nil, center_signature: nil, actor: nil, request: nil)
    self.guardian_name = guardian_name
    self.guardian_signature.attach(guardian_signature) if guardian_signature.present?
    self.center_signature.attach(center_signature) if center_signature.present?

    data = ContractPdf.new(self).render
    pdf.attach(io: StringIO.new(data), filename: "#{number}.pdf", content_type: "application/pdf")

    update!(status: "signed", signed_at: Time.current, signed_by: actor,
            sha256: Digest::SHA256.hexdigest(data),
            ip: request&.remote_ip, user_agent: request&.user_agent.to_s.first(255),
            snapshot: build_snapshot)
  end

  def build_snapshot
    {
      "student" => student.name,
      "birthdate" => student.birthdate&.to_s,
      "guardian" => guardian_name,
      "pool" => pool.name,
      "teacher" => enrollment.swim_class.teacher.display_name,
      "class_code" => enrollment.swim_class.code,
      "class_type" => "1:#{enrollment.swim_class.class_type}",
      "schedule" => enrollment.swim_class.slot_label,
      "package" => enrollment.package&.name,
      "sessions" => enrollment.total_available,
      "amount" => enrollment.order&.total,
      "expires_on" => enrollment.expires_on&.to_s
    }
  end

  private

  def assign_number
    self.number ||= "CK#{Time.current.strftime('%y%m')}#{SecureRandom.random_number(10_000).to_s.rjust(4, '0')}"
  end
end
