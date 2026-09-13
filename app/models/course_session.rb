# Giáo án mặc định của một buổi trong khoá (FR-212). Giáo viên được phép sửa nội
# dung cho riêng buổi mình dạy — bản sửa đó nằm ở Lesson#content_override, không
# đụng vào giáo án gốc.
class CourseSession < ApplicationRecord
  acts_as_tenant(:workspace)

  belongs_to :workspace
  belongs_to :course

  validates :position, presence: true, uniqueness: { scope: :course_id }
  validates :title, presence: true

  scope :ordered, -> { order(:position) }

  def label = "Buổi #{position} · #{title}"
end
