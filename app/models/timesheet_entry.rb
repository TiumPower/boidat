# Một dòng công của giáo viên cho một buổi dạy. Được tính TỰ ĐỘNG từ dữ liệu
# điểm danh (FR-210 — màn hình chấm công chỉ đọc, không ai nhập tay).
class TimesheetEntry < ApplicationRecord
  acts_as_tenant(:workspace)

  belongs_to :workspace
  belongs_to :pool
  belongs_to :teacher
  belongs_to :lesson
  belongs_to :payroll_period, optional: true

  scope :pending, -> { where(status: "pending") }
  scope :locked,  -> { where(status: "locked") }
  scope :in_range, ->(from, to) { joins(:lesson).where(lessons: { date: from..to }) }

  def locked? = status == "locked"
  def basis_label = basis == "registered" ? "sĩ số đăng ký" : "số có mặt"
end
