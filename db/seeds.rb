# Seed idempotent — chạy lại bao nhiêu lần cũng ra cùng một kết quả.
# Dữ liệu demo lấy đúng theo bộ UX/UI của BƠI ĐẠT: 3 hồ (Quận 7, Thủ Đức,
# Gò Vấp), các giáo viên và hộ gia đình có thật trong bản thiết kế, để khi đối
# chiếu app thật với file HTML mockup thì tên và số liệu khớp nhau.

require "faker"
Faker::Config.locale = "vi"

PASSWORD = ENV.fetch("SEED_PASSWORD", "boidat1234")

puts "→ Gói thuê bao nền tảng"
Plan.seed_defaults!

puts "→ Super Admin nền tảng"
admin = AdminUser.find_or_initialize_by(email: "quocvietlee@gmail.com")
admin.assign_attributes(name: "Quốc Việt", role: "superadmin") if admin.new_record?
admin.password = PASSWORD if admin.new_record?
admin.save!

puts "→ Trung tâm BƠI ĐẠT"
ws = Workspace.find_or_initialize_by(subdomain: "boidat")
ws.assign_attributes(
  name: "BƠI ĐẠT", status: "active", plan: "pro", locale_default: "vi",
  paid_until: 1.year.from_now,
  branding: { "tagline" => "Trung tâm dạy bơi", "city" => "TP. Hồ Chí Minh",
              "contact_phone" => "0909118247" }
)
ws.save!
WorkspaceBootstrap.call(ws)

ActsAsTenant.with_tenant(ws) do
  # ---- Hồ bơi (FR-111) --------------------------------------------------
  puts "→ 3 hồ bơi"
  pools_data = [
    { name: "Hồ Quận 7",   code: "Q7", address: "12 Nguyễn Lương Bằng, Q7",   position: 0 },
    { name: "Hồ Thủ Đức",  code: "TD", address: "48 Võ Văn Ngân, TP Thủ Đức", position: 1 },
    { name: "Hồ Gò Vấp",   code: "GV", address: "203 Quang Trung, Gò Vấp",    position: 2 }
  ]
  pools = pools_data.map do |attrs|
    pool = Pool.find_or_initialize_by(workspace: ws, name: attrs[:name])
    pool.assign_attributes(attrs.merge(status: "active"))
    pool.save!

    # Giờ mở cửa: T2–T7 06:00–21:00, Chủ nhật nửa ngày 06:00–12:00.
    (0..6).each do |wd|
      row = PoolOperatingHour.find_or_initialize_by(workspace: ws, pool: pool, weekday: wd)
      if wd.zero?
        row.assign_attributes(opens_at: "06:00", closes_at: "12:00", closed: false)
      else
        row.assign_attributes(opens_at: "06:00", closes_at: "21:00", closed: false)
      end
      row.save!
    end
    pool
  end
  q7, thu_duc, go_vap = pools

  # ---- Nhân sự (FR-113, FR-218) -----------------------------------------
  puts "→ Nhân sự"
  def upsert_user!(email:, name:, phone: nil, title: nil, password: PASSWORD)
    u = User.find_or_initialize_by(email: email)
    u.assign_attributes(name: name, phone: phone, title: title, locale: "vi")
    u.password = password if u.new_record?
    u.save!
    u
  end

  def assign!(ws, user, role, pools)
    m = Membership.find_or_initialize_by(user: user, workspace: ws)
    m.role = role
    m.status = "active"
    m.save!
    Array(pools).each do |pool|
      PoolAssignment.find_or_create_by!(workspace: ws, pool: pool, user: user)
    end
    m
  end

  bod = upsert_user!(email: "bod@boidat.vn", name: "Trần Văn Đạt", phone: "0903111222")
  assign!(ws, bod, "bod", pools)

  staff = [
    { email: "hoang@boidat.vn", name: "Nguyễn Huy Hoàng", role: "admin", pools: [q7, thu_duc],   phone: "0903000111" },
    { email: "tram@boidat.vn",  name: "Đỗ Ngọc Trâm",     role: "sale",  pools: [q7, go_vap],    phone: "0903000222" },
    { email: "duy@boidat.vn",   name: "Lâm Khánh Duy",    role: "sale",  pools: [thu_duc],       phone: "0903000333" },
    { email: "ngan@boidat.vn",  name: "Bùi Kim Ngân",     role: "receptionist", pools: [q7],     phone: "0903000444" },
    { email: "thao@boidat.vn",  name: "Trịnh Thu Thảo",   role: "receptionist", pools: [thu_duc], phone: "0903000555" },
    { email: "hoa@boidat.vn",   name: "Phan Tường Vy",    role: "receptionist", pools: [go_vap], phone: "0903000666" }
  ]
  staff.each do |s|
    u = upsert_user!(email: s[:email], name: s[:name], phone: s[:phone])
    assign!(ws, u, s[:role], s[:pools])
  end

  # ---- Giáo viên (FR-209, FR-216) ---------------------------------------
  puts "→ Giáo viên & cấp độ"
  levels = TeacherLevel.ordered.index_by(&:name)

  teachers_data = [
    { email: "minh@boidat.vn",  name: "Trần Quang Minh",  title: "Thầy", level: "Level 3", pools: [q7, go_vap],
      specialty: "Trẻ em sợ nước", years: 8,  phone: "0909118247" },
    { email: "hanh@boidat.vn",  name: "Nguyễn Thu Hạnh",  title: "Cô",   level: "Level 2", pools: [q7],
      specialty: "Bơi ếch", years: 5,  phone: "0909118248" },
    { email: "tuan@boidat.vn",  name: "Lê Anh Tuấn",      title: "Thầy", level: "Level 3", pools: [q7, thu_duc],
      specialty: "Người lớn", years: 10, phone: "0909118249" },
    { email: "lan@boidat.vn",   name: "Phạm Mỹ Lan",      title: "Cô",   level: "Level 1", pools: [q7],
      specialty: "Mầm non", years: 2,  phone: "0909118250" },
    { email: "yen@boidat.vn",   name: "Đinh Hải Yến",     title: "Cô",   level: "Level 2", pools: [thu_duc],
      specialty: "Trẻ em", years: 4,  phone: "0909118251" },
    { email: "truong@boidat.vn", name: "Bùi Nhật Trường", title: "Thầy", level: "Level 3", pools: [thu_duc],
      specialty: "Bơi sải", years: 7,  phone: "0909118252" },
    { email: "van@boidat.vn",   name: "Hồ Thanh Vân",     title: "Cô",   level: "Level 2", pools: [go_vap],
      specialty: "An toàn nước", years: 5, phone: "0909118253" },
    { email: "phuc@boidat.vn",  name: "Ngô Gia Phúc",     title: "Thầy", level: "Level 4", pools: [go_vap],
      specialty: "Nâng cao", years: 12, phone: "0909118254" },
    { email: "son@boidat.vn",   name: "Hoàng Bảo Sơn",    title: "Thầy", level: "Level 2", pools: [q7],
      specialty: "Trẻ em", years: 3, phone: "0909118255", status: "on_leave" }
  ]
  teachers_data.each do |t|
    u = upsert_user!(email: t[:email], name: t[:name], phone: t[:phone], title: t[:title])
    assign!(ws, u, "teacher", t[:pools])
    teacher = Teacher.find_or_initialize_by(workspace: ws, user: u)
    teacher.assign_attributes(teacher_level: levels[t[:level]], kind: "staff",
                              status: t[:status] || "active", specialty: t[:specialty],
                              years_experience: t[:years])
    teacher.save!
    t[:pools].each { |p| TeacherPool.find_or_create_by!(workspace: ws, teacher: teacher, pool: p) }
  end

  # Giáo viên THUÊ HỒ (FR-225) — luồng rút gọn, không chấm công/giáo án.
  khoa_user = upsert_user!(email: "khoa@caheo.vn", name: "Võ Đăng Khoa", title: "Thầy", phone: "0909118260")
  assign!(ws, khoa_user, "teacher", [q7])
  khoa = Teacher.find_or_initialize_by(workspace: ws, user: khoa_user)
  khoa.assign_attributes(kind: "renter", status: "active", org_name: "CLB Cá Heo", teacher_level: nil)
  khoa.save!
  TeacherPool.find_or_create_by!(workspace: ws, teacher: khoa, pool: q7)


  # ---- Khoá học & giáo án (FR-212) --------------------------------------
  puts "→ Khoá học & giáo án"
  # Giáo án 12 buổi của khoá cơ bản — lấy đúng chuỗi mục tiêu trong bộ UX.
  BASIC_PLAN = [
    ["Làm quen nước, thở bọt", "Hết sợ nước"],
    ["Nổi ngửa có phao",       "Nổi 10 giây"],
    ["Đạp chân tự do có phao", "Đạp 10m"],
    ["Đạp chân không phao",    "Đạp 10m không phao"],
    ["Quạt tay tự do",         "Phối hợp tay"],
    ["Thở nghiêng",            "Thở không sặc nước"],
    ["Phối hợp tay chân",      "Bơi 10m"],
    ["Thở nghiêng + tay",      "Bơi 15m"],
    ["Tăng cự ly tự do",       "Bơi 15m liên tục"],
    ["Đạp chân ếch",           "Đạp đúng kỹ thuật"],
    ["Ôn tập & an toàn nước",  "Đủ điều kiện thi"],
    ["Hoàn thiện & kiểm tra thử", "Bơi 25m liên tục"]
  ].freeze

  courses_data = [
    { name: "Bơi cơ bản trẻ em", audience: "child",  class_types: [1, 2, 3, 4], plan: BASIC_PLAN },
    { name: "Bơi ếch nâng cao",  audience: "child",  class_types: [1, 2, 3] },
    { name: "Người lớn cơ bản",  audience: "adult",  class_types: [1, 2] },
    { name: "Kỹ năng an toàn nước", audience: "child", class_types: [2, 3, 4] }
  ]
  courses = courses_data.map do |c|
    course = Course.find_or_initialize_by(workspace: ws, name: c[:name])
    course.assign_attributes(audience: c[:audience], class_types: c[:class_types], status: "active")
    course.save!
    course.ensure_session_plan!
    if c[:plan]
      c[:plan].each_with_index do |(title, goal), i|
        cs = CourseSession.find_by(workspace: ws, course: course, position: i + 1)
        # OQ-25 đã chốt: cả 12 buổi đều là buổi học, kỳ thi xếp riêng.
        cs&.update!(title: title, goal: goal, exam: false)
      end
    end
    course
  end
  basic = courses.first

  # ---- Gói sản phẩm & bảng giá (FR-213, FR-214) -------------------------
  puts "→ Gói sản phẩm & bảng giá"
  packages_data = [
    { name: "Khoá 12 buổi trẻ em 1:1", kind: "full_course", course: basic, class_type: 1, sessions: 12,
      price: 9_600_000, description: "Kèm riêng · hạn dùng 1 năm · có thi tốt nghiệp" },
    { name: "Khoá 12 buổi trẻ em 1:2", kind: "full_course", course: basic, class_type: 2, sessions: 12,
      price: 4_800_000, description: "Hạn dùng 1 năm · có thi tốt nghiệp" },
    { name: "Khoá 12 buổi trẻ em 1:3", kind: "full_course", course: basic, class_type: 3, sessions: 12,
      price: 3_600_000, description: "Lớp nhóm 3 bạn" },
    { name: "Khoá 12 buổi trẻ em 1:4", kind: "full_course", course: basic, class_type: 4, sessions: 12,
      price: 3_000_000, description: "Lớp nhóm 4 bạn" },
    { name: "Gói lẻ 4 buổi", kind: "per_session", course: basic, class_type: 2, sessions: 4,
      price: 1_800_000, validity_days: 180, description: "Linh hoạt giờ · hạn 6 tháng" },
    { name: "Vé bơi tự do", kind: "day_pass", course: nil, class_type: nil, sessions: 1,
      price: 80_000, validity_days: 1, description: "Dùng 1 lần · QR một lần, không cần đăng ký khuôn mặt" },
    { name: "Thuê hồ theo giờ", kind: "pool_rental", course: nil, class_type: nil, sessions: nil,
      price: 300_000, description: "Giáo viên ngoài thuê giờ dạy học viên của họ" }
  ]
  packages_data.each_with_index do |p, idx|
    pkg = Package.find_or_initialize_by(workspace: ws, name: p[:name])
    pkg.assign_attributes(kind: p[:kind], course: p[:course], class_type: p[:class_type],
                          sessions: p[:sessions], validity_days: p[:validity_days],
                          description: p[:description], status: "active", position: idx)
    pkg.save!
    unless pkg.price_list_items.exists?
      PriceListItem.create!(workspace: ws, package: pkg, pool: nil, price: p[:price],
                            effective_from: Date.current.beginning_of_year)
    end
  end

  # ---- Khuyến mãi (OQ-17) -----------------------------------------------
  puts "→ Khuyến mãi"
  promos = [
    { name: "Tặng 1 buổi khi đăng ký khoá 12 buổi", kind: "bonus_sessions", value: 1,
      condition_note: "Áp dụng học viên mới · tháng 9" },
    { name: "Giảm 10% khi tái ký trong 30 ngày", kind: "percent_off", value: 10,
      condition_note: "Tự gợi ý khi học viên còn ≤2 buổi" },
    { name: "Ưu đãi anh chị em ruột", kind: "sibling", value: 5,
      condition_note: "Từ học viên thứ 2 cùng gia đình" },
    { name: "Quà tặng: kính bơi + mũ", kind: "gift", value: 0, stock: 24,
      condition_note: "Khoá 1:1 · trao tại quầy buổi đầu" },
    { name: "Voucher giới thiệu bạn", kind: "referral_voucher", value: 200_000,
      condition_note: "Người giới thiệu nhận sau khi bạn đóng đủ" }
  ]
  promos.each do |pr|
    promo = Promotion.find_or_initialize_by(workspace: ws, name: pr[:name])
    promo.assign_attributes(pr.merge(status: "active"))
    promo.save!
  end

  # ---- Hộ gia đình & học viên (FR-206, FR-204) --------------------------
  puts "→ Hộ gia đình & học viên"
  households_data = [
    { household: "Gia đình Trần Văn Đạt", pool: q7,
      guardians: [{ name: "Nguyễn Văn Hùng", phone: "0908221447", role: "owner", relation: "Bố" },
                  { name: "Trần Thị Hương",  phone: "0908221448", role: "pickup", relation: "Mẹ" }],
      students: [{ name: "Trần Bảo Ngọc", birthdate: "2018-04-12", gender: "nữ" },
                 { name: "Nguyễn Gia Bảo", birthdate: "2019-09-02", gender: "nam",
                   health_notes: "Hen suyễn nhẹ — cho nghỉ giữa hiệp nếu thở gấp." }] },
    { household: "Gia đình Vũ Trọng Kiên", pool: q7,
      guardians: [{ name: "Vũ Trọng Kiên", phone: "0912004556", role: "owner", relation: "Bố" }],
      students: [{ name: "Vũ Gia Hân", birthdate: "2017-02-20", gender: "nữ" },
                 { name: "Vũ Anh Thư", birthdate: "2015-06-08", gender: "nữ" }] },
    { household: "Gia đình Đỗ Trung Hiếu", pool: q7,
      guardians: [{ name: "Đỗ Trung Hiếu", phone: "0977812330", role: "owner", relation: "Bố" }],
      students: [{ name: "Đỗ Minh Khôi", birthdate: "2016-11-30", gender: "nam" }] },
    { household: "Gia đình Ngô Văn Thành", pool: q7,
      guardians: [{ name: "Ngô Văn Thành", phone: "0933112255", role: "owner", relation: "Bố" }],
      students: [{ name: "Ngô Bảo An", birthdate: "2018-01-15", gender: "nam" }] },
    { household: "Gia đình Lâm Quốc Cường", pool: q7,
      guardians: [{ name: "Lâm Quốc Cường", phone: "0933112266", role: "owner", relation: "Bố" }],
      students: [{ name: "Lâm Khánh Vy", birthdate: "2017-07-19", gender: "nữ" }] },
    { household: "Gia đình Bùi Anh Đức", pool: q7,
      guardians: [{ name: "Bùi Anh Đức", phone: "0933112277", role: "owner", relation: "Bố" }],
      students: [{ name: "Bùi Tuệ Nhi", birthdate: "2018-03-03", gender: "nữ" }] },
    { household: "Gia đình Đặng Quốc Nga", pool: q7,
      guardians: [{ name: "Đặng Quốc Nga", phone: "0933112288", role: "owner", relation: "Mẹ" }],
      students: [{ name: "Đặng Hà My", birthdate: "2016-05-25", gender: "nữ" }] },
    { household: "Gia đình Hồ Đình Nam", pool: thu_duc,
      guardians: [{ name: "Hồ Đình Nam", phone: "0933112299", role: "owner", relation: "Bố" }],
      students: [{ name: "Hồ Thanh Trúc", birthdate: "2017-10-10", gender: "nữ" }] },
    { household: "Gia đình Lý Thành Trung", pool: thu_duc,
      guardians: [{ name: "Lý Thành Trung", phone: "0933112300", role: "owner", relation: "Bố" }],
      students: [{ name: "Lý Gia Huy", birthdate: "2015-12-01", gender: "nam" }] },
    { household: "Gia đình Phan Văn Mai", pool: go_vap,
      guardians: [{ name: "Phan Văn Mai", phone: "0933112311", role: "owner", relation: "Bố" }],
      students: [{ name: "Phan Linh Đan", birthdate: "2018-08-08", gender: "nữ" }] },
    { household: "Gia đình Trương Hữu Phước", pool: go_vap,
      guardians: [{ name: "Trương Hữu Phước", phone: "0933112322", role: "owner", relation: "Bố" }],
      students: [{ name: "Trương Quốc Bảo", birthdate: "2016-02-14", gender: "nam" }] },
    { household: "Gia đình Nguyễn Văn Dũng", pool: thu_duc,
      guardians: [{ name: "Nguyễn Văn Dũng", phone: "0933112333", role: "owner", relation: "Bố" },
                  { name: "Lê Thị Yến", phone: "0933112334", role: "pickup", relation: "Bà" }],
      students: [{ name: "Nguyễn Gia Bảo (TĐ)", birthdate: "2017-01-09", gender: "nam" }] },
    { household: "Gia đình Mai Xuân Hùng", pool: thu_duc,
      guardians: [{ name: "Mai Xuân Hùng", phone: "0933112344", role: "owner", relation: "Bố" }],
      students: [{ name: "Mai Đức Anh", birthdate: "2016-06-21", gender: "nam" }] },
    { household: "Gia đình Tạ Công Sơn", pool: thu_duc,
      guardians: [{ name: "Tạ Công Sơn", phone: "0933112355", role: "owner", relation: "Bố" }],
      students: [{ name: "Tạ Phương Vy", birthdate: "2018-11-02", gender: "nữ" }] },
    { household: "Gia đình Lê Hoài Nam", pool: go_vap,
      guardians: [{ name: "Lê Hoài Nam", phone: "0933112366", role: "owner", relation: "Bố" }],
      students: [{ name: "Lê Nam Phong", birthdate: "2015-04-17", gender: "nam" }] },
    { household: "Gia đình Đinh Thảo Nguyên", pool: go_vap,
      guardians: [{ name: "Đinh Thảo Nguyên", phone: "0933112377", role: "owner", relation: "Mẹ" }],
      students: [{ name: "Ngô Bảo Trâm", birthdate: "2017-09-28", gender: "nữ" }] }
  ]

  households_data.each do |h|
    hh = Household.find_or_initialize_by(workspace: ws, name: h[:household])
    hh.kind = "family"
    hh.save!
    h[:guardians].each do |g|
      guardian = Guardian.find_or_initialize_by(workspace: ws, household: hh, name: g[:name])
      guardian.assign_attributes(phone: g[:phone], role: g[:role], relation: g[:relation])
      guardian.save!
    end
    h[:students].each do |s|
      st = Student.find_or_initialize_by(workspace: ws, household: hh, name: s[:name])
      st.assign_attributes(pool: h[:pool], birthdate: s[:birthdate], gender: s[:gender],
                           health_notes: s[:health_notes], kind: "center", status: "active",
                           source: %w[Giới\ thiệu Facebook Google Vãng\ lai].sample)
      st.save!
    end
  end

  # Người lớn tự học (UX phụ huynh, màn 3b): hộ "individual", vừa là chủ hộ vừa là học viên.
  solo = Household.find_or_initialize_by(workspace: ws, name: "Phạm Quốc Duy")
  solo.kind = "individual"
  solo.save!
  solo_guardian = Guardian.find_or_initialize_by(workspace: ws, household: solo, name: "Phạm Quốc Duy")
  solo_guardian.assign_attributes(phone: "0987654321", role: "owner", is_student: true)
  solo_guardian.save!
  solo_student = Student.find_or_initialize_by(workspace: ws, household: solo, name: "Phạm Quốc Duy")
  solo_student.assign_attributes(pool: q7, birthdate: "1994-03-20", gender: "nam",
                                 guardian: solo_guardian, kind: "center", status: "active")
  solo_student.save!

  # Học viên của giáo viên thuê hồ (FR-225) — không có hồ sơ học tập.
  rental_hh = Household.find_or_initialize_by(workspace: ws, name: "CLB Cá Heo")
  rental_hh.kind = "family"
  rental_hh.save!
  rental_guardian = Guardian.find_or_initialize_by(workspace: ws, household: rental_hh, name: "Võ Đăng Khoa")
  rental_guardian.assign_attributes(phone: "0909118260", role: "owner")
  rental_guardian.save!
  ["Lê Minh Sang", "Trương Gia Hưng", "Nguyễn Khả Vy", "Đỗ Thành Long"].each do |name|
    st = Student.find_or_initialize_by(workspace: ws, household: rental_hh, name: name)
    st.assign_attributes(pool: q7, kind: "renter", status: "active")
    st.save!
  end


  # ---- Lịch đăng ký dạy, lớp và buổi học (FR-304, FR-202) ---------------
  puts "→ Lịch dạy & lớp học"
  # Mỗi giáo viên đăng ký các khung giờ cố định cho tháng này và tháng sau, để
  # bảng master data có cả slot đã có lớp lẫn slot còn trống ngay sau khi seed.
  SHIFT_HOURS = [6, 7, 8, 16, 17, 18, 19].freeze
  months = [Date.current.beginning_of_month, Date.current.next_month.beginning_of_month]

  Teacher.staff.active.includes(:pools).find_each do |teacher|
    teacher.pools.each do |pool|
      months.each do |month|
        (1..6).each do |weekday|            # T2 → T7
          SHIFT_HOURS.each do |hour|
            next unless pool.slot_hours_on(month + (weekday - month.wday) % 7).include?(hour)
            TeacherAvailability.find_or_create_by!(
              workspace: ws, teacher: teacher, pool: pool,
              month: month, weekday: weekday, hour: hour
            ) { |a| a.submitted_at = Time.current }
          end
        end
      end
    end
  end

  # Vài lớp đang chạy ở hồ Quận 7 — đúng các lớp có trong bộ UX.
  basic_course = Course.find_by(name: "Bơi cơ bản trẻ em")
  pkg_1v2 = Package.find_by(name: "Khoá 12 buổi trẻ em 1:2")
  pkg_1v3 = Package.find_by(name: "Khoá 12 buổi trẻ em 1:3")

  def open_class!(ws:, pool:, teacher:, course:, package:, class_type:, weekdays:, hour:, start_date:, students:, used: 0)
    cls = SwimClass.find_or_initialize_by(workspace: ws, pool: pool, teacher: teacher,
                                          start_hour: hour, start_date: start_date)
    cls.assign_attributes(course: course, class_type: class_type, weekdays: weekdays,
                          status: "running", kind: "class")
    cls.save!
    LessonGenerator.new(cls).call

    students.each_with_index do |student, i|
      next if student.nil?
      enr = Enrollment.find_or_initialize_by(workspace: ws, student: student, swim_class: cls)
      next unless enr.new_record?
      enr.assign_attributes(pool: pool, package: package, starts_on: start_date,
                            sessions_total: package&.session_count || cls.total_sessions,
                            customer_type: i.zero? ? "new" : "returning", status: "active")
      enr.save!
      # Ghi nhận số buổi đã học để màn hình có tiến độ thật.
      enr.update!(sessions_used: used)
      enr.check_exam_eligibility!

      Order.find_or_create_by!(workspace: ws, enrollment: enr) do |o|
        o.pool = pool
        o.household = student.household
        o.student = student
        o.package = package
        o.amount = package&.price_for(pool).to_i
        o.kind = "course"
        o.customer_type = enr.customer_type
        o.status = i.even? ? "paid" : "unpaid"
        # Ghi nhận trong tháng hiện tại để dashboard demo có số liệu thật.
        o.paid_at = i.even? ? [start_date.to_time, Date.current.beginning_of_month.to_time].max + 2.days : nil
      end
    end
    cls
  end

  by_name = Student.where(pool: q7).index_by(&:name)
  minh = Teacher.joins(:user).find_by(users: { email: "minh@boidat.vn" })
  hanh = Teacher.joins(:user).find_by(users: { email: "hanh@boidat.vn" })
  tuan = Teacher.joins(:user).find_by(users: { email: "tuan@boidat.vn" })

  open_class!(ws: ws, pool: q7, teacher: minh, course: basic_course, package: pkg_1v2,
              class_type: 2, weekdays: [1, 3], hour: 17, start_date: 8.weeks.ago.to_date.beginning_of_week,
              students: [by_name["Trần Bảo Ngọc"], by_name["Nguyễn Gia Bảo"]], used: 8)

  open_class!(ws: ws, pool: q7, teacher: minh, course: basic_course, package: pkg_1v2,
              class_type: 2, weekdays: [1, 3], hour: 6, start_date: 5.weeks.ago.to_date.beginning_of_week,
              students: [by_name["Vũ Gia Hân"], by_name["Đỗ Minh Khôi"]], used: 5)

  open_class!(ws: ws, pool: q7, teacher: minh, course: basic_course, package: pkg_1v3,
              class_type: 3, weekdays: [2, 4], hour: 7, start_date: 2.weeks.ago.to_date.beginning_of_week,
              students: [by_name["Ngô Bảo An"], by_name["Lâm Khánh Vy"], by_name["Bùi Tuệ Nhi"]], used: 2)

  open_class!(ws: ws, pool: q7, teacher: hanh, course: basic_course, package: pkg_1v2,
              class_type: 2, weekdays: [2, 4], hour: 16, start_date: 10.weeks.ago.to_date.beginning_of_week,
              students: [by_name["Đặng Hà My"], by_name["Vũ Anh Thư"]], used: 11)

  open_class!(ws: ws, pool: q7, teacher: tuan, course: basic_course, package: pkg_1v2,
              class_type: 2, weekdays: [5], hour: 19, start_date: 3.weeks.ago.to_date.beginning_of_week,
              students: [by_name["Phạm Quốc Duy"]], used: 5)

  # Lớp ở hai hồ còn lại — để chuyển hồ trên sidebar là thấy dữ liệu ngay.
  td_by_name = Student.where(pool: thu_duc, kind: "center").index_by(&:name)
  gv_by_name = Student.where(pool: go_vap, kind: "center").index_by(&:name)
  yen     = Teacher.joins(:user).find_by(users: { email: "yen@boidat.vn" })
  truong  = Teacher.joins(:user).find_by(users: { email: "truong@boidat.vn" })
  van     = Teacher.joins(:user).find_by(users: { email: "van@boidat.vn" })
  phuc    = Teacher.joins(:user).find_by(users: { email: "phuc@boidat.vn" })

  open_class!(ws: ws, pool: thu_duc, teacher: yen, course: basic_course, package: pkg_1v2,
              class_type: 2, weekdays: [1, 4], hour: 17, start_date: 6.weeks.ago.to_date.beginning_of_week,
              students: [td_by_name["Hồ Thanh Trúc"], td_by_name["Nguyễn Gia Bảo (TĐ)"]], used: 6)

  open_class!(ws: ws, pool: thu_duc, teacher: truong, course: basic_course, package: pkg_1v3,
              class_type: 3, weekdays: [2, 5], hour: 18, start_date: 3.weeks.ago.to_date.beginning_of_week,
              students: [td_by_name["Lý Gia Huy"], td_by_name["Mai Đức Anh"], td_by_name["Tạ Phương Vy"]],
              used: 3)

  open_class!(ws: ws, pool: go_vap, teacher: van, course: basic_course, package: pkg_1v2,
              class_type: 2, weekdays: [3, 6], hour: 16, start_date: 9.weeks.ago.to_date.beginning_of_week,
              students: [gv_by_name["Phan Linh Đan"], gv_by_name["Trương Quốc Bảo"]], used: 9)

  open_class!(ws: ws, pool: go_vap, teacher: phuc, course: basic_course, package: pkg_1v2,
              class_type: 2, weekdays: [1, 4], hour: 19, start_date: 11.weeks.ago.to_date.beginning_of_week,
              students: [gv_by_name["Lê Nam Phong"], gv_by_name["Ngô Bảo Trâm"]], used: 11)

  # Giờ giáo viên thuê hồ chiếm chỗ trên bảng lịch (FR-225) — không chấm công,
  # không giáo án, chỉ để slot đó hiện là "đã bận".
  rental_students = Student.where(pool: q7, kind: "renter").to_a
  rental_class = SwimClass.find_or_initialize_by(workspace: ws, pool: q7, teacher: khoa,
                                                 start_hour: 6, start_date: 4.weeks.ago.to_date.beginning_of_week)
  rental_class.assign_attributes(class_type: 4, weekdays: [2, 4, 6], status: "running", kind: "rental", course: nil)
  rental_class.save!
  LessonGenerator.new(rental_class).call(total: 24)
  rental_students.each do |st|
    enr = Enrollment.find_or_initialize_by(workspace: ws, student: st, swim_class: rental_class)
    next unless enr.new_record?
    enr.assign_attributes(pool: q7, sessions_total: 10, sessions_used: rand(0..7), status: "active")
    enr.save!
  end


  # ---- Điểm danh & công cho các buổi đã qua ------------------------------
  puts "→ Điểm danh & chấm công"
  receptionist = User.find_by(email: "ngan@boidat.vn")
  SwimClass.classes.running.includes(:lessons, enrollments: :student).find_each do |cls|
    cls.lessons.where("date < ?", Date.current).order(:session_index).each do |lesson|
      cls.enrollments.select { |e| e.status == "active" }.each do |enr|
        next if lesson.attendances.exists?(student_id: enr.student_id)
        # 92% đi học — phần còn lại là vắng không báo, để dashboard có số liệu thật.
        next if rand > 0.92
        Attendance.create!(workspace: ws, pool: cls.pool, lesson: lesson, student: enr.student,
                           enrollment: enr, actor: receptionist, status: "present",
                           method: %w[face face face manual].sample, deducted: true,
                           checked_in_at: lesson.starts_at - rand(5..25).minutes)
      end
      lesson.update!(status: "done", completed_at: lesson.starts_at + 1.hour) if lesson.attendances.any?
      PayrollCalculator.new(lesson.reload).call
    end
  end

  # Nhận xét của giáo viên cho các buổi gần nhất.
  FEEDBACK_SAMPLES = [
    ["progress",   "Đã thở nghiêng được 15m liên tục, tay vào nước còn hơi rộng."],
    ["progress",   "Bắt đầu quen nhịp thở, không còn sặc nước."],
    ["needs_work", "Phối hợp còn gấp, cần thả lỏng vai. Đã bơi được 10m không phao."],
    ["progress",   "Tay quạt đúng kỹ thuật, chân còn yếu."]
  ].freeze
  Lesson.where(status: "done").where("date >= ?", 3.weeks.ago).includes(:attendances, :swim_class).find_each do |lesson|
    next if lesson.swim_class.rental?
    lesson.attendances.select { |a| a.status == "present" }.each do |att|
      next if SessionFeedback.exists?(lesson: lesson, student_id: att.student_id)
      tag, body = FEEDBACK_SAMPLES.sample
      SessionFeedback.create!(workspace: ws, pool: lesson.pool, lesson: lesson,
                              student_id: att.student_id, teacher: lesson.teacher,
                              tag: tag, body: body, sent_at: lesson.starts_at + 2.hours)
    end
  end


  # ---- Chat & cam kết ----------------------------------------------------
  puts "→ Chat & cam kết"
  admin_user = User.find_by(email: "hoang@boidat.vn")
  CHAT_SAMPLES = [
    ["guardian", "Chào em, bé Bảo tuần sau đi công tác với gia đình, xin nghỉ thứ 4 được không?"],
    ["staff",    "Dạ được ạ. Chị vào mục “Xin vắng” trên app để đổi buổi, buổi đó sẽ không bị trừ ạ."],
    ["staff",    "Em gửi chị lịch trống của thầy Minh thứ 6 nhé."],
    ["guardian", "Chị làm được rồi, cảm ơn em nhé!"]
  ].freeze

  Household.where(id: Student.where(pool: q7, kind: "center").select(:household_id)).limit(4).each_with_index do |hh, idx|
    conv = Conversation.for_household(hh, q7)
    next if conv.messages.any?
    CHAT_SAMPLES.first(idx.zero? ? 4 : 2).each_with_index do |(kind, body), i|
      msg = conv.messages.create!(workspace: ws, sender_kind: kind, body: body,
                                  user: kind == "staff" ? admin_user : nil,
                                  guardian: kind == "guardian" ? hh.owner : nil,
                                  created_at: (4 - i).hours.ago)
      conv.update!(last_message_at: msg.created_at, last_preview: body.truncate(80))
    end
    conv.update!(staff_unread: conv.messages.where(sender_kind: "guardian").count > 1 ? 0 : 1)
  end

  # Cam kết đã ký cho các lớp đã chạy được một thời gian.
  Enrollment.active.includes(:student, swim_class: :teacher).limit(4).each do |enr|
    next if enr.contract
    contract = Contract.create!(workspace: ws, pool: enr.pool, enrollment: enr,
                                household: enr.student.household,
                                guardian_name: enr.student.household.owner&.name)
    contract.update!(status: "signed", signed_at: enr.starts_on, signed_by: admin_user,
                     snapshot: contract.build_snapshot,
                     sha256: Digest::SHA256.hexdigest("#{contract.number}-seed"))
  end


  # ---- Dữ liệu demo cho các luồng còn lại --------------------------------
  # Mục tiêu: mỗi cổng mở lên là có việc để xem, không màn hình nào trống.
  puts "→ Dữ liệu demo cho từng cổng"

  # Ngày nghỉ lễ sắp tới ở một hồ — để thấy lịch bị chặn đúng chỗ.
  PoolHoliday.find_or_create_by!(workspace: ws, pool: q7, date: Date.current + 12) do |h|
    h.reason = "Bảo trì hệ thống lọc nước"
  end

  # Ảnh khuôn mặt: phần lớn đã đăng ký, vài em chưa (để PWA phụ huynh có việc
  # phải làm), một em bị gắn cờ chụp lại vì tỷ lệ quét lỗi cao (OQ-01).
  Student.where(kind: "center").order(:id).each_with_index do |student, idx|
    next if idx % 5 == 3 # cứ 5 em thì để 1 em chưa có ảnh
    profile = FaceProfile.find_or_initialize_by(workspace: ws, student: student)
    next unless profile.new_record?
    profile.assign_attributes(external_ref: "#{ws.id}:#{student.id}", embedding_version: "buffalo_l",
                              quality: (0.72 + rand * 0.2).round(3), samples_count: 3,
                              captured_at: rand(1..10).months.ago,
                              scan_count: rand(6..20), fail_count: 0)
    profile.save!
    profile.update!(fail_count: (profile.scan_count * 0.4).round, recapture_flag: true) if idx == 6
    BiometricConsent.find_or_create_by!(workspace: ws, student: student) do |c|
      c.guardian = student.household.owner
      c.terms_version = BiometricConsent::CURRENT_TERMS_VERSION
      c.consented_at = profile.captured_at
      c.ip = "113.161.0.#{rand(2..250)}"
      c.user_agent = "Mozilla/5.0 (iPhone; CPU iPhone OS 17_5 like Mac OS X)"
    end
  end

  # Học viên đã đủ điều kiện thi tốt nghiệp (FR-208) — cần đúng mốc buổi.
  target = ws.graduation_at_session
  Enrollment.active.includes(:student).order(:id).first(3).each_with_index do |enr, i|
    enr.update!(sessions_used: target + i - 1)
    enr.check_exam_eligibility!
  end
  # Một em đã có kết quả thi để màn hình kết quả không trống.
  if (graded = Enrollment.active.where.not(exam_eligible_at: nil).first)
    graded.update!(exam_date: 5.days.ago.to_date, exam_result: "passed")
  end

  # Đơn xin nghỉ đang chờ Admin duyệt (FR-211) — mở cổng vận hành là thấy việc.
  upcoming = Lesson.where(teacher: minh, status: "scheduled")
                   .where("date >= ?", Date.current).order(:date, :start_hour).limit(2).pluck(:id)
  if upcoming.any? && LeaveRequest.where(teacher: minh, status: "pending").none?
    LeaveRequest.create!(workspace: ws, teacher: minh, lesson_ids: upcoming,
                         reason: "Việc gia đình, em nhờ trung tâm sắp xếp lịch bù giúp học viên ạ.",
                         status: "pending", submitted_at: 1.day.ago)
  end
  # Một đơn đã duyệt trước đó, kèm yêu cầu học bù phụ huynh chưa chọn phương án.
  past_lesson = Lesson.where(teacher: hanh, status: "done").order(:date).last
  if past_lesson && LeaveRequest.where(teacher: hanh).none?
    approved = LeaveRequest.create!(workspace: ws, teacher: hanh, lesson_ids: [past_lesson.id],
                                    reason: "Tập huấn cứu hộ", status: "approved",
                                    submitted_at: 10.days.ago, reviewed_at: 9.days.ago,
                                    reviewed_by: User.find_by(email: "hoang@boidat.vn"))
    past_lesson.swim_class.active_enrollments.each do |enr|
      MakeupRequest.find_or_create_by!(workspace: ws, enrollment: enr, from_lesson: past_lesson) do |m|
        m.pool = past_lesson.pool
        m.student = enr.student
        m.leave_request = approved
        m.origin = "teacher_leave"
        m.status = "pending"
        m.reason = approved.reason
      end
    end
  end

  # Thông báo cho phụ huynh, gồm một cái BẮT BUỘC XÁC NHẬN còn treo (OQ-16) —
  # để màn hình "cần gọi điện" của admin có dữ liệu thật.
  Guardian.where(role: "owner").limit(6).each_with_index do |g, i|
    next if Notification.where(recipient: g).exists?
    Notification.create!(workspace: ws, recipient: g, kind: "lesson_reminder",
                         title: "Nhắc buổi học ngày mai",
                         body: "Đến sớm 15 phút và quét khuôn mặt tại quầy trước khi xuống nước.",
                         deep_link: "/", created_at: 1.day.ago)
    next unless i < 3
    Notification.create!(workspace: ws, recipient: g, kind: "teacher_leave",
                         title: "Cô Hạnh nghỉ buổi #{I18n.l(Date.current + 3, format: '%d/%m')}",
                         body: "Buổi này không bị trừ. Chọn một phương án cho con.",
                         requires_ack: true, deep_link: "/notifications", created_at: 6.hours.ago)
  end

  # Vé lẻ trong ngày (FR-214) — một vé đã dùng, một vé còn hiệu lực.
  day_pass = Package.find_by(kind: "day_pass")
  if day_pass && DayPassTicket.where(pool: q7, valid_on: Date.current).none?
    2.times do |i|
      order = Order.create!(workspace: ws, pool: q7, package: day_pass,
                            sale: User.find_by(email: "tram@boidat.vn"),
                            amount: day_pass.price_for(q7).to_i * (i + 1), kind: "day_pass",
                            status: "paid", paid_at: Time.current - (i + 1).hours,
                            note: ["Khách vãng lai", "Nhóm 2 khách"][i])
      order.payments.create!(workspace: ws, amount: order.amount, method: "cash",
                             paid_at: order.paid_at)
      ticket = DayPassTicket.create!(workspace: ws, pool: q7, order: order,
                                     issued_by: order.sale, quantity: i + 1,
                                     guest_name: ["Anh Hoàng", "Chị Ngân"][i],
                                     guest_phone: ["0912888111", "0912888222"][i],
                                     valid_on: Date.current)
      ticket.redeem! if i.zero?
    end
  end

  # Doanh thu cho thuê hồ (OQ-26) — dòng riêng trên dashboard.
  if Order.where(kind: "rental").none?
    rental_order = Order.create!(workspace: ws, pool: q7, sale: User.find_by(email: "hoang@boidat.vn"),
                                 amount: 12_000_000, kind: "rental", status: "paid",
                                 paid_at: Date.current.beginning_of_month + 4.days,
                                 note: "CLB Cá Heo · 40 giờ × 300.000đ")
    rental_order.payments.create!(workspace: ws, amount: rental_order.amount, method: "transfer",
                                  paid_at: rental_order.paid_at)
  end

  # Đơn đã thanh toán phải có bản ghi thu tiền tương ứng, nếu không màn hình chi
  # tiết đơn hiện "đã thanh toán" mà lịch sử thu tiền trống — nhìn như lỗi.
  Order.paid.includes(:payments).each do |order|
    next if order.payments.any?
    order.payments.create!(workspace: ws, amount: order.total,
                           method: %w[payos cash transfer].sample,
                           paid_at: order.paid_at || order.created_at)
  end

  # Kỳ chốt công đã khoá (FR-210) — giáo viên thấy lịch sử kỳ lương.
  period_start = Date.current.beginning_of_month
  period_end = [period_start + 14, Date.current - 1].min
  if period_end > period_start && PayrollPeriod.where(pool: q7, starts_on: period_start).none?
    period = PayrollPeriod.create!(workspace: ws, pool: q7, starts_on: period_start, ends_on: period_end)
    period.lock!(by: bod)
  end

  # Bản nháp xếp lịch tháng sau (FR-205) — mở màn hình là có cái để duyệt.
  next_month = Date.current.next_month.beginning_of_month
  if ScheduleRun.where(pool: q7, month: next_month).none?
    AutoScheduler.new(pool: q7, month: next_month, workspace: ws)
                 .build_draft(created_by: User.find_by(email: "hoang@boidat.vn"))
  end

  puts "   #{Pool.count} hồ · #{Teacher.count} giáo viên · #{Course.count} khoá · #{Package.count} gói · " \
       "#{Household.count} hộ · #{Student.count} học viên · #{SwimClass.count} lớp · #{Lesson.count} buổi · " \
       "#{TeacherAvailability.count} ca đăng ký · #{Attendance.count} lượt điểm danh · " \
       "#{TimesheetEntry.count} dòng công"
end

puts <<~INFO

  ────────────────────────────────────────────────────────────
  Đăng nhập demo (mật khẩu: #{PASSWORD})
    Super Admin nền tảng  /admin/login   quocvietlee@gmail.com
    BOD                   /login         bod@boidat.vn
    Admin quản lý hồ      /login         hoang@boidat.vn
    Sale                  /login         tram@boidat.vn
    Lễ tân (quầy)         /login         ngan@boidat.vn
    Giáo viên             /login         minh@boidat.vn
    Giáo viên thuê hồ     /login         khoa@caheo.vn

  Phụ huynh: mở /w/boidat → quét/dán mã QR của hộ (in ở màn Học viên),
  hoặc người lớn tự học đăng nhập bằng SĐT 0987654321 (mã OTP hiện trên màn hình).
  ────────────────────────────────────────────────────────────
INFO
