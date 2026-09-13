# Dữ liệu tối thiểu để một trung tâm mới dùng được ngay: bảng level giáo viên
# mặc định (FR-216) và các tham số nghiệp vụ default (BusinessSettings).
module WorkspaceBootstrap
  module_function

  DEFAULT_LEVELS = [
    { name: "Level 1", position: 0, max_students_per_slot: 1, pay_rate_per_credit: 60_000,
      description: "Mới vào nghề, kèm cặp" },
    { name: "Level 2", position: 1, max_students_per_slot: 2, pay_rate_per_credit: 75_000,
      description: "Dạy độc lập" },
    { name: "Level 3", position: 2, max_students_per_slot: 3, pay_rate_per_credit: 90_000,
      description: "Dạy nhóm & nâng cao" },
    { name: "Level 4", position: 3, max_students_per_slot: 4, pay_rate_per_credit: 110_000,
      description: "Trưởng nhóm chuyên môn" }
  ].freeze

  def call(workspace)
    ActsAsTenant.with_tenant(workspace) do
      workspace.update!(settings: workspace.settings.reverse_merge("onboarded" => false))
      DEFAULT_LEVELS.each do |attrs|
        lvl = TeacherLevel.find_or_initialize_by(workspace: workspace, name: attrs[:name])
        lvl.assign_attributes(attrs) if lvl.new_record?
        lvl.save!
      end
    end
    workspace
  end
end
