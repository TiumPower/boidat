class PushSubscription < ApplicationRecord
  acts_as_tenant(:workspace)

  belongs_to :workspace
  belongs_to :guardian, optional: true   # PWA phụ huynh
  belongs_to :user,     optional: true   # PWA giáo viên & quầy điểm danh

  validates :endpoint, :p256dh, :auth, presence: true

  def self.store_for_guardian!(guardian:, endpoint:, p256dh:, auth:)
    sub = find_or_initialize_by(guardian_id: guardian.id, endpoint: endpoint)
    sub.workspace = guardian.workspace
    sub.update!(p256dh: p256dh, auth: auth)
    sub
  end

  def self.store_for_user!(user:, workspace:, endpoint:, p256dh:, auth:)
    sub = find_or_initialize_by(user_id: user.id, endpoint: endpoint)
    sub.workspace = workspace
    sub.update!(p256dh: p256dh, auth: auth)
    sub
  end
end
