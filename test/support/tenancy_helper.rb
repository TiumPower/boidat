# Dựng một trung tâm đầy đủ vai trò để test — dùng chung cho mọi integration test.
module TenancyHelper
  Setup = Struct.new(:workspace, :pools, :users, :teacher, :household, :guardian, :student,
                     keyword_init: true)

  def build_center!(pools: 2)
    ws = create(:workspace)
    ActsAsTenant.with_tenant(ws) do
      pool_list = Array.new(pools) { |i| create(:pool, workspace: ws, name: "Hồ #{i + 1}", position: i) }
      pool_list.each do |pool|
        (0..6).each do |wd|
          PoolOperatingHour.create!(workspace: ws, pool: pool, weekday: wd,
                                    opens_at: "06:00", closes_at: "21:00")
        end
      end

      users = {}
      %w[bod admin sale receptionist teacher].each do |role|
        u = create(:user, name: "#{role.capitalize} test")
        Membership.create!(user: u, workspace: ws, role: role)
        # BOD nhìn mọi hồ; các vai trò khác chỉ được gán hồ đầu tiên.
        assigned = role == "bod" ? pool_list : [pool_list.first]
        assigned.each { |p| PoolAssignment.create!(workspace: ws, pool: p, user: u) }
        users[role.to_sym] = u
      end

      level = create(:teacher_level, workspace: ws)
      teacher = Teacher.create!(workspace: ws, user: users[:teacher], teacher_level: level,
                                kind: "staff", status: "active")
      TeacherPool.create!(workspace: ws, teacher: teacher, pool: pool_list.first)

      household = create(:household, workspace: ws)
      guardian  = create(:guardian, workspace: ws, household: household)
      student   = create(:student, workspace: ws, household: household, pool: pool_list.first)

      Setup.new(workspace: ws, pools: pool_list, users: users, teacher: teacher,
                household: household, guardian: guardian, student: student)
    end
  end
end
