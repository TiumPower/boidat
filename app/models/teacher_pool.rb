class TeacherPool < ApplicationRecord
  acts_as_tenant(:workspace)

  belongs_to :workspace
  belongs_to :teacher
  belongs_to :pool

  validates :teacher_id, uniqueness: { scope: :pool_id }
end
