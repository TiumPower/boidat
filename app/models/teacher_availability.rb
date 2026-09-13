# Khung giờ giáo viên đăng ký sẵn sàng dạy trong một tháng (FR-304).
# Đây là đầu vào bắt buộc của bộ xếp lịch tự động và là nguồn của "slot trống"
# trên bảng master data — slot trống = đã đăng ký dạy nhưng chưa có học viên.
class TeacherAvailability < ApplicationRecord
  acts_as_tenant(:workspace)

  belongs_to :workspace
  belongs_to :teacher
  belongs_to :pool

  validates :weekday, inclusion: { in: 0..6 }
  validates :hour, inclusion: { in: 0..23 }

  scope :for_month, ->(date) { where(month: date.beginning_of_month) }
  scope :submitted, -> { where.not(submitted_at: nil) }

  def self.month_key(date) = date.to_date.beginning_of_month

  # Ghi đè toàn bộ đăng ký của một giáo viên trong tháng bằng lựa chọn mới.
  # `slots` là mảng "pool_id:weekday:hour".
  def self.replace_month!(teacher:, month:, slots:, submitted: false)
    month = month_key(month)
    wanted = Array(slots).filter_map do |raw|
      pool_id, weekday, hour = raw.to_s.split(":").map(&:to_i)
      next if pool_id.zero?
      { pool_id: pool_id, weekday: weekday, hour: hour }
    end

    transaction do
      where(teacher: teacher, month: month).destroy_all
      wanted.each do |attrs|
        create!(workspace: teacher.workspace, teacher: teacher, month: month,
                submitted_at: submitted ? Time.current : nil, **attrs)
      end
    end
    wanted.size
  end

  # Cùng một giáo viên không được đăng ký trùng khung giờ ở hai hồ khác nhau —
  # lỗi nhập liệu rất dễ xảy ra khi ba hồ do ba admin quản lý (OQ-24).
  def self.conflicts_for(teacher, month)
    for_month(month).where(teacher: teacher)
                    .group(:weekday, :hour).having("COUNT(DISTINCT pool_id) > 1").count.keys
  end
end
