require "test_helper"

# Cam kết ký điện tử (FR-207) + giới hạn pháp lý đã trao đổi với khách (OQ-15).
class ContractTest < ActiveSupport::TestCase
  setup do
    @c = build_center!
    @ws = @c.workspace
    with_tenant(@ws) do
      course = Course.create!(workspace: @ws, name: "Bơi cơ bản")
      course.ensure_session_plan!
      cls = SwimClass.create!(workspace: @ws, pool: @c.pools.first, teacher: @c.teacher, course: course,
                              class_type: 2, start_hour: 17, weekdays: [1], start_date: Date.current)
      @enrollment = Enrollment.create!(workspace: @ws, pool: @c.pools.first, student: @c.student,
                                       swim_class: cls, sessions_total: 12, status: "active")
      @contract = Contract.create!(workspace: @ws, pool: @c.pools.first, enrollment: @enrollment,
                                   household: @c.household, guardian_name: @c.guardian.name)
    end
  end

  test "ký thì sinh PDF, băm file và lưu audit trail" do
    with_tenant(@ws) do
      @contract.sign!(guardian_name: "Nguyễn Văn Hùng", actor: @c.users[:sale])
      @contract.reload

      assert @contract.signed?
      assert @contract.pdf.attached?, "phải sinh file PDF"
      assert_equal 64, @contract.sha256.length, "SHA-256 hex là 64 ký tự"
      assert @contract.signed_at.present?
      assert_equal "Nguyễn Văn Hùng", @contract.guardian_name
    end
  end

  test "snapshot chốt lại số liệu tại thời điểm ký" do
    with_tenant(@ws) do
      @contract.sign!(guardian_name: @c.guardian.name)
      snapshot = @contract.reload.snapshot
      assert_equal @c.student.name, snapshot["student"]
      assert_equal 12, snapshot["sessions"]

      # Sau này đổi gói cũng không làm sai lệch bản đã ký.
      @enrollment.update!(sessions_total: 20)
      assert_equal 12, @contract.reload.snapshot["sessions"]
    end
  end

  test "mã băm tính trên file cuối cùng — file đổi thì băm đổi" do
    with_tenant(@ws) do
      @contract.sign!(guardian_name: "A")
      first = @contract.sha256
      @contract.sign!(guardian_name: "B")
      refute_equal first, @contract.reload.sha256
    end
  end

  test "PDF sinh ra là file PDF hợp lệ" do
    with_tenant(@ws) do
      @contract.sign!(guardian_name: @c.guardian.name)
      assert_equal "%PDF", @contract.pdf.download[0, 4]
    end
  end
end
