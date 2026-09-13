# FR-222 — thông báo tự động khi tạo lớp mới cho học viên.
# Thời điểm bắn: ngay khi Admin/Sale xác nhận tạo lớp (không đợi ký cam kết).
# Hai nhóm người nhận, hai nội dung khác nhau — giáo viên cần biết có học viên
# mới vào lớp của mình, phụ huynh cần biết lịch học và gói đã mua.
class ClassCreatedNotifier
  def initialize(enrollment:)
    @enrollment = enrollment
    @student = enrollment.student
    @swim_class = enrollment.swim_class
    @workspace = enrollment.workspace
  end

  def call
    notify_teacher
    notify_guardians
  end

  private

  def notify_teacher
    user = @swim_class.teacher.user
    Notification.create!(
      workspace: @workspace, recipient: user, kind: "class_created",
      title: "Học viên mới vào lớp #{@swim_class.code}",
      body: "#{@student.name} · #{@swim_class.slot_label} · lớp 1:#{@swim_class.class_type} · " \
            "bắt đầu #{I18n.l(@swim_class.start_date, format: '%d/%m')} · " \
            "#{@enrollment.total_available} buổi",
      subject: @swim_class, deep_link: "/teacher"
    )
    PushJob.perform_later(@workspace.id, "User", [user.id],
                          "Học viên mới vào lớp", "#{@student.name} · #{@swim_class.slot_label}", "/teacher")
  end

  def notify_guardians
    guardians = @student.household.guardians.to_a
    return if guardians.empty?

    title = "#{@student.name} đã có lớp"
    body = "#{@swim_class.teacher.display_name} · 1:#{@swim_class.class_type} · " \
           "#{@swim_class.slot_label} · #{@enrollment.total_available} buổi · " \
           "bắt đầu #{I18n.l(@swim_class.start_date, format: '%d/%m')}"

    guardians.each do |g|
      Notification.create!(workspace: @workspace, recipient: g, kind: "class_created",
                           title: title, body: body, subject: @swim_class, deep_link: "/")
    end
    PushJob.perform_later(@workspace.id, "Guardian", guardians.map(&:id), title, body, "/")
  end
end
