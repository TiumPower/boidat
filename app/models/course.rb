class Course < ApplicationRecord
  acts_as_tenant(:workspace)

  AUDIENCES = %w[child adult].freeze
  AUDIENCE_LABELS = { "child" => "Trẻ em", "adult" => "Người lớn" }.freeze

  belongs_to :workspace
  has_many :course_sessions, -> { order(:position) }, dependent: :destroy
  has_many :packages, dependent: :nullify
  has_many :swim_classes, dependent: :nullify

  validates :name, presence: true
  validates :audience, inclusion: { in: AUDIENCES }

  scope :ordered, -> { order(:position, :name) }
  scope :active,  -> { where(status: "active") }

  accepts_nested_attributes_for :course_sessions, allow_destroy: true

  def active? = status == "active"
  def audience_label = AUDIENCE_LABELS[audience]

  # Vòng đời khoá: giá trị riêng của khoá thắng, không có thì lấy cấu hình chung
  # của trung tâm (BusinessSettings) — để mở khoá mới không phải khai lại từ đầu.
  def total_sessions      = sessions_count.presence || workspace.course_session_count
  def graduation_session  = graduation_at_session.presence || workspace.graduation_at_session
  def exam_session        = exam_session_index.presence || workspace.exam_session_index
  def expiry_days         = validity_days.presence || workspace.package_validity_days

  def allowed_class_types = Array(class_types).map(&:to_i).select(&:positive?).presence || [1, 2, 3, 4]

  def class_type_label = allowed_class_types.map { |n| "1:#{n}" }.join(", ")

  # Giáo án của buổi thứ n (dùng khi sinh buổi học và khi giáo viên mở chi tiết buổi).
  def plan_for(index) = course_sessions.find { |s| s.position == index }

  # Tạo sẵn khung giáo án trống cho đủ số buổi, để admin điền dần.
  def ensure_session_plan!
    (1..total_sessions).each do |i|
      next if course_sessions.exists?(position: i)
      course_sessions.create!(workspace: workspace, position: i,
                              title: i == exam_session ? "Thi tốt nghiệp" : "Buổi #{i}",
                              exam: i == exam_session)
    end
  end
end
