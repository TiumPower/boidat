# Kỳ chốt công (FR-210). Chốt xong thì các dòng công trong kỳ khoá lại, điểm
# danh sửa sau đó không làm thay đổi số tiền đã chốt.
class PayrollPeriod < ApplicationRecord
  acts_as_tenant(:workspace)

  belongs_to :workspace
  belongs_to :pool, optional: true
  belongs_to :locked_by, class_name: "User", optional: true
  has_many :timesheet_entries, dependent: :nullify

  validates :starts_on, :ends_on, presence: true

  scope :recent, -> { order(starts_on: :desc) }

  def locked? = locked_at.present?
  def label = "#{I18n.l(starts_on, format: '%d/%m')} – #{I18n.l(ends_on, format: '%d/%m/%Y')}"

  # Gom mọi dòng công chưa khoá trong kỳ rồi khoá lại.
  def lock!(by:)
    entries = TimesheetEntry.where(pool_id: pool_id.presence || TimesheetEntry.select(:pool_id))
                            .where(payroll_period_id: nil, status: "pending")
                            .joins(:lesson).where(lessons: { date: starts_on..ends_on })
    entries = entries.where(pool_id: pool_id) if pool_id
    transaction do
      entries.update_all(payroll_period_id: id, status: "locked")
      reload
      update!(locked_at: Time.current, locked_by: by,
              total_credits: timesheet_entries.sum(:credits),
              total_amount: timesheet_entries.sum(:amount))
    end
  end
end
