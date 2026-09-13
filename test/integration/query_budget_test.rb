require "test_helper"

# Ngân sách truy vấn cho các màn hình danh sách.
#
# N+1 là loại lỗi không nhìn thấy được ở quy mô demo và chí tử ở quy mô thật:
# với 20 học viên nó tốn thêm vài mili-giây, với 2.000 học viên thì trang treo.
# Đo bằng cách nhân dữ liệu lên rồi khẳng định số truy vấn KHÔNG tăng theo —
# tức là thêm bản ghi không được đẻ thêm câu lệnh SQL.
class QueryBudgetTest < ActionDispatch::IntegrationTest
  setup do
    @c = build_center!
    @ws = @c.workspace
    @pool = @c.pools.first
    host_workspace!(@ws)
    sign_in @c.users[:bod]
  end

  # Đếm SELECT thật, bỏ qua schema và giao dịch.
  #
  # Phải xoá query cache trước mỗi lần đo. Trong integration test, cache của
  # Rails sống xuyên các request trong cùng một test, nên lần GET thứ hai ăn
  # cache sạch và phép đo trả về 0 — bộ đo tưởng như xanh trong khi thực chất
  # nó không đo gì cả. Đã dính đúng bẫy này một lần khi viết bộ test.
  def count_queries
    n = 0
    sub = ActiveSupport::Notifications.subscribe("sql.active_record") do |*, payload|
      next if payload[:name].to_s =~ /SCHEMA|TRANSACTION/
      n += 1 if payload[:sql] =~ /\ASELECT/i
    end
    ActiveRecord::Base.connection.clear_query_cache
    yield
    n
  ensure
    ActiveSupport::Notifications.unsubscribe(sub)
  end

  def seed_students!(count)
    with_tenant(@ws) do
      count.times do |i|
        hh = create(:household, workspace: @ws, name: "Hộ #{i}")
        create(:guardian, workspace: @ws, household: hh)
        create(:student, workspace: @ws, household: hh, pool: @pool, name: "HV #{i}")
      end
    end
  end

  def assert_flat(path, label)
    seed_students!(3)
    get path
    assert_response :success
    few = count_queries { get path }

    seed_students!(12)
    get path
    many = count_queries { get path }

    growth = many - few
    assert growth <= 3,
           "#{label}: thêm 12 học viên làm số truy vấn tăng #{growth} " \
           "(#{few} → #{many}). Dấu hiệu N+1 — thiếu includes/preload."
  end

  test "danh sách học viên không N+1" do
    assert_flat "/merchant/ops/students", "Danh sách học viên"
  end

  test "danh sách hộ gia đình không N+1" do
    assert_flat "/merchant/ops/households", "Hộ gia đình"
  end

  test "dashboard BOD không N+1 theo số học viên" do
    assert_flat "/merchant/bod", "Dashboard BOD"
  end
end
