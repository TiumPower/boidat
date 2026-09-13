# Nhật ký thao tác (FR-221 / FR-116). Chỉ ghi thao tác GHI và các lần đọc dữ liệu
# nhạy cảm — log cả thao tác đọc thường thì DB phình rất nhanh (OQ-19).
class AuditLog < ApplicationRecord
  acts_as_tenant(:workspace)

  ACTIONS = %w[create update destroy read_sensitive login].freeze

  belongs_to :workspace
  belongs_to :pool, optional: true
  belongs_to :user, optional: true

  validates :action, inclusion: { in: ACTIONS }

  scope :recent, -> { order(created_at: :desc) }
  scope :for_entity, ->(type, id) { where(entity_type: type, entity_id: id) }

  # Trường nhạy cảm không bao giờ được ghi nguyên văn vào nhật ký.
  FILTERED = %w[encrypted_password password code qr_token auth p256dh embedding].freeze

  def self.record!(action:, entity:, user: nil, pool: nil, summary: nil, before: nil, after: nil, request: nil)
    ws = entity.try(:workspace) || ActsAsTenant.current_tenant
    return nil if ws.nil?

    create!(
      workspace: ws, pool: pool || entity.try(:pool), user: user,
      actor_label: user&.name,
      action: action.to_s, entity_type: entity.class.name, entity_id: entity.try(:id),
      summary: summary,
      changes_before: sanitize(before), changes_after: sanitize(after),
      ip: request&.remote_ip, user_agent: request&.user_agent.to_s.first(255)
    )
  rescue => e
    # Nhật ký hỏng không được phép làm hỏng nghiệp vụ.
    Rails.logger.warn("[audit] #{e.class}: #{e.message}")
    nil
  end

  def self.sanitize(hash)
    return {} if hash.blank?
    hash.to_h.except(*FILTERED)
  end

  def action_label
    { "create" => "Tạo", "update" => "Sửa", "destroy" => "Xoá",
      "read_sensitive" => "Xem dữ liệu nhạy cảm", "login" => "Đăng nhập" }[action] || action
  end
end
