require "test_helper"

# Cổng điều hành: CRUD hồ bơi, nhân sự, giáo viên, cấp độ và cấu hình nghiệp vụ.
class BodMasterDataTest < ActionDispatch::IntegrationTest
  setup do
    @c = build_center!
    @ws = @c.workspace
    host_workspace!(@ws)
    sign_in @c.users[:bod]
  end

  test "tạo hồ mới thì sinh sẵn giờ mở cửa cả tuần" do
    assert_difference -> { with_tenant(@ws) { Pool.count } }, 1 do
      post "/merchant/bod/pools", params: { pool: { name: "Hồ Gò Vấp", code: "GV", address: "203 Quang Trung" } }
    end
    pool = with_tenant(@ws) { Pool.find_by(name: "Hồ Gò Vấp") }
    assert_equal 7, with_tenant(@ws) { pool.operating_hours.count }
    assert pool.open_on?(Date.current)
  end

  test "không xoá được hồ còn học viên — buộc chuyển sang đóng cửa" do
    pool = @c.pools.first
    delete "/merchant/bod/pools/#{pool.id}"
    assert_match "còn học viên", flash[:alert]
    assert with_tenant(@ws) { Pool.exists?(pool.id) }
  end

  test "ngày nghỉ khiến hồ đóng cửa hôm đó" do
    pool = @c.pools.first
    post "/merchant/bod/pools/#{pool.id}/holidays", params: { date: Date.current.to_s, reason: "Bảo trì" }
    assert with_tenant(@ws) { !pool.reload.open_on?(Date.current) }
  end

  test "gán nhân sự cho hồ, gỡ gán không xoá dữ liệu" do
    pool = @c.pools.last
    sale = @c.users[:sale]
    patch "/merchant/bod/pools/#{pool.id}/assign_staff", params: { user_ids: [sale.id] }
    assert with_tenant(@ws) { PoolAssignment.exists?(pool: pool, user: sale) }

    patch "/merchant/bod/pools/#{pool.id}/assign_staff", params: { user_ids: [] }
    refute with_tenant(@ws) { PoolAssignment.exists?(pool: pool, user: sale) }
    assert with_tenant(@ws) { Student.exists?(@c.student.id) }
  end

  test "tạo tài khoản nhân sự: admin tự đặt mật khẩu, không có vai trò BOD" do
    refute_includes Merchant::Bod::StaffController::ASSIGNABLE_ROLES, "bod"

    post "/merchant/bod/staff", params: {
      user: { name: "Lễ tân mới", email: "letan.moi@boidat.vn", password: "matkhau123" },
      role: "receptionist", pool_ids: [@c.pools.first.id]
    }
    user = User.find_by(email: "letan.moi@boidat.vn")
    assert user, "chưa tạo được tài khoản"
    assert user.valid_password?("matkhau123"), "mật khẩu admin đặt phải dùng được ngay"
    assert_equal "receptionist", user.role_in(@ws)
    assert_match "matkhau123", flash[:notice], "phải hiện mật khẩu để admin gửi cho nhân sự"
  end

  test "chọn vai trò giáo viên thì tự tạo luôn hồ sơ Teacher" do
    post "/merchant/bod/staff", params: {
      user: { name: "Cô Mới", email: "comoi@boidat.vn" }, role: "teacher", pool_ids: [@c.pools.first.id]
    }
    user = User.find_by(email: "comoi@boidat.vn")
    assert with_tenant(@ws) { Teacher.exists?(user_id: user.id) }
  end

  test "khoá tài khoản chỉ gỡ quyền, giữ lại người dùng và nhật ký" do
    membership = @ws.memberships.find_by(user: @c.users[:sale])
    delete "/merchant/bod/staff/#{membership.id}"
    assert_equal "suspended", membership.reload.status
    assert User.exists?(@c.users[:sale].id)
  end

  test "đặt lại mật khẩu trả mã mới ngay trên màn hình" do
    membership = @ws.memberships.find_by(user: @c.users[:sale])
    patch "/merchant/bod/staff/#{membership.id}/reset_password"
    assert_match(/Mật khẩu mới/, flash[:notice])
  end

  test "sửa cấu hình nghiệp vụ là đổi hành vi, không cần sửa code" do
    patch "/merchant/bod/settings", params: {
      settings: { credit_table: { "1" => "0.5", "2" => "1.0", "3" => "1.5", "4" => "1.5" },
                  credit_basis: "present", course_sessions: "10", graduation_at_session: "9" }
    }
    @ws.reload
    assert_equal 1.5, @ws.credits_for(4), "đặt trần công lớp 1:4"
    refute @ws.credit_basis_registered?
    assert_equal 10, @ws.course_session_count
    assert_equal 9, @ws.graduation_at_session
  end

  test "đổi bộ màu áp cho toàn bộ workspace" do
    patch "/merchant/bod/appearance", params: { preset: "clay_pink" }
    assert_equal "#B8536B", @ws.reload.theme_value(:primary)
  end

  test "mọi thao tác ghi đều vào nhật ký" do
    assert_difference -> { with_tenant(@ws) { AuditLog.count } }, 1 do
      post "/merchant/bod/pools", params: { pool: { name: "Hồ Test" } }
    end
    log = with_tenant(@ws) { AuditLog.recent.first }
    assert_equal "create", log.action
    assert_equal @c.users[:bod].name, log.actor_label
  end
end
