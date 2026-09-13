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
    ["Thi tốt nghiệp",         "Bơi 25m liên tục"]
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
        cs&.update!(title: title, goal: goal, exam: (i + 1) == course.exam_session)
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
      students: [{ name: "Trương Quốc Bảo", birthdate: "2016-02-14", gender: "nam" }] }
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

  puts "   #{Pool.count} hồ · #{Teacher.count} giáo viên · #{Course.count} khoá · #{Package.count} gói · " \
       "#{Household.count} hộ · #{Student.count} học viên"
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
