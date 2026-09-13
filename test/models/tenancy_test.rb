require "test_helper"

# Hai trục phân quyền là nền móng — nếu nó rò rỉ thì mọi thứ phía trên vô nghĩa.
class TenancyTest < ActiveSupport::TestCase
  setup do
    @a = build_center!(pools: 2)
    @b = build_center!(pools: 1)
  end

  test "dữ liệu của trung tâm này không lọt sang trung tâm khác" do
    with_tenant(@a.workspace) do
      assert_equal 2, Pool.count
      assert_includes Student.pluck(:id), @a.student.id
      refute_includes Student.pluck(:id), @b.student.id
    end
  end

  test "BOD thấy mọi hồ, nhân sự khác chỉ thấy hồ được gán" do
    with_tenant(@a.workspace) do
      assert_equal 2, @a.users[:bod].accessible_pools(@a.workspace).count
      assert_equal [@a.pools.first.id], @a.users[:sale].accessible_pools(@a.workspace).pluck(:id)
    end
  end

  test "gỡ gán hồ chỉ cắt quyền, không xoá dữ liệu đã phát sinh" do
    with_tenant(@a.workspace) do
      student_id = @a.student.id
      PoolAssignment.where(user: @a.users[:sale], pool: @a.pools.first).destroy_all
      assert_equal 0, @a.users[:sale].reload.accessible_pools(@a.workspace).count
      assert Student.exists?(student_id)
    end
  end

  test "học viên khoá cứng theo hồ đã đăng ký (OQ-23)" do
    with_tenant(@a.workspace) do
      assert @a.student.attendable_at?(@a.pools.first)
      refute @a.student.attendable_at?(@a.pools.last), "không được điểm danh ở hồ khác"
    end
  end

  test "chủ hộ xem được thanh toán, người đưa đón thì không (OQ-03)" do
    with_tenant(@a.workspace) do
      pickup = create(:guardian, workspace: @a.workspace, household: @a.household, role: "pickup")
      assert @a.guardian.can_view_payments?
      refute pickup.can_view_payments?

      # Trung tâm nào muốn cho tất cả xem thì chỉ cần đổi cấu hình.
      @a.workspace.update_business_settings!("household_scope_payments" => "everyone")
      assert pickup.reload.can_view_payments?
    end
  end

  test "cấp lại QR làm mã cũ hết hiệu lực" do
    with_tenant(@a.workspace) do
      old = @a.household.qr_token
      @a.household.reissue_qr!
      refute_equal old, @a.household.reload.qr_token
      assert @a.household.qr_active?
    end
  end
end
