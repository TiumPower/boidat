# Gán nhân sự vào hồ (FR-112). Gỡ gán chỉ cắt quyền truy cập, không đụng tới dữ
# liệu lịch sử người đó đã tạo.
class PoolAssignment < ApplicationRecord
  acts_as_tenant(:workspace)

  belongs_to :workspace
  belongs_to :pool
  belongs_to :user

  validates :user_id, uniqueness: { scope: :pool_id }
end
