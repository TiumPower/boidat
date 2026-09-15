require "test_helper"

# Xoá hẳn một trung tâm: thao tác phá huỷ nhiều nhất trong hệ thống, và cho tới
# giờ chưa có test nào. Nó xoá theo DANH SÁCH TÊN BẢNG viết tay, mà danh sách
# ấy trôi theo schema — bỏ `otp_challenges` khỏi CSDL là câu DELETE cho bảng đó
# ném PG::UndefinedTable giữa transaction và việc xoá trung tâm hỏng hẳn.
class WorkspacePurgeTest < ActiveSupport::TestCase
  setup do
    @doomed  = build_center!
    @keep    = build_center!
  end

  test "xoá sạch mọi dữ liệu của trung tâm bị xoá" do
    wid = @doomed.workspace.id
    WorkspacePurge.call(@doomed.workspace)

    refute Workspace.exists?(wid)
    ActsAsTenant.without_tenant do
      [Pool, Student, Household, Guardian, Teacher, Membership, PoolAssignment].each do |model|
        assert_equal 0, model.where(workspace_id: wid).count,
                     "#{model.name} còn sót dữ liệu của trung tâm đã xoá"
      end
    end
  end

  test "không đụng tới trung tâm khác" do
    keep_id = @keep.workspace.id
    students = ActsAsTenant.without_tenant { Student.where(workspace_id: keep_id).count }
    assert students.positive?

    WorkspacePurge.call(@doomed.workspace)

    assert Workspace.exists?(keep_id)
    ActsAsTenant.without_tenant do
      assert_equal students, Student.where(workspace_id: keep_id).count
    end
  end

  # Danh sách tên bảng viết tay sẽ lệch khỏi schema sớm muộn. Lệch thì phải bỏ
  # qua chứ không được làm hỏng cả thao tác xoá.
  test "bảng trong danh sách mà không còn tồn tại thì bỏ qua, không nổ" do
    wid = @doomed.workspace.id
    WorkspacePurge.stub_const_delete_order(WorkspacePurge::DELETE_ORDER + ["bang_khong_ton_tai"]) do
      assert_nothing_raised { WorkspacePurge.call(@doomed.workspace) }
    end
    refute Workspace.exists?(wid)
  end
end

# Thay tạm hằng số DELETE_ORDER cho đúng một khối, rồi trả lại.
class WorkspacePurge
  def self.stub_const_delete_order(list)
    original = DELETE_ORDER
    send(:remove_const, :DELETE_ORDER)
    const_set(:DELETE_ORDER, list.freeze)
    yield
  ensure
    send(:remove_const, :DELETE_ORDER)
    const_set(:DELETE_ORDER, original)
  end
end
