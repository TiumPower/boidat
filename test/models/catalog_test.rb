require "test_helper"

# Danh mục sản phẩm: vòng đời khoá, bảng giá theo hồ và theo thời gian.
class CatalogTest < ActiveSupport::TestCase
  setup do
    @c = build_center!
    @ws = @c.workspace
  end

  test "khoá học lấy vòng đời từ cấu hình trung tâm khi không khai riêng" do
    with_tenant(@ws) do
      course = Course.create!(workspace: @ws, name: "Bơi cơ bản")
      assert_equal @ws.course_session_count, course.total_sessions
      assert_equal @ws.graduation_at_session, course.graduation_session
      assert_equal @ws.package_validity_days, course.expiry_days
    end
  end

  test "khoá khai riêng số buổi thì thắng cấu hình chung" do
    with_tenant(@ws) do
      course = Course.create!(workspace: @ws, name: "Nâng cao", sessions_count: 8,
                              graduation_at_session: 7, exam_session_index: 8)
      assert_equal 8, course.total_sessions
      assert_equal 7, course.graduation_session
    end
  end

  test "sinh khung giáo án đủ số buổi, mặc định không buổi nào là buổi thi (OQ-25)" do
    with_tenant(@ws) do
      course = Course.create!(workspace: @ws, name: "Bơi cơ bản")
      course.ensure_session_plan!
      assert_equal course.total_sessions, course.course_sessions.count
      assert_nil course.exam_session, "kỳ thi xếp riêng ngoài khoá"
      assert_equal 0, course.course_sessions.where(exam: true).count
    end
  end

  test "khoá nào muốn gộp buổi thi vào trong thì khai exam_session_index" do
    with_tenant(@ws) do
      course = Course.create!(workspace: @ws, name: "Khoá có buổi thi", sessions_count: 10,
                              exam_session_index: 10)
      course.ensure_session_plan!
      exam = course.course_sessions.find_by(position: 10)
      assert exam.exam
      assert_equal "Thi tốt nghiệp", exam.title
    end
  end

  test "chạy lại ensure_session_plan! không tạo trùng" do
    with_tenant(@ws) do
      course = Course.create!(workspace: @ws, name: "Bơi cơ bản")
      course.ensure_session_plan!
      assert_no_difference -> { course.course_sessions.count } do
        course.reload.ensure_session_plan!
      end
    end
  end

  test "giá riêng của hồ thắng giá chung" do
    with_tenant(@ws) do
      pkg = Package.create!(workspace: @ws, name: "Khoá 12 buổi", kind: "full_course", class_type: 2, sessions: 12)
      PriceListItem.create!(workspace: @ws, package: pkg, pool: nil, price: 4_800_000)
      PriceListItem.create!(workspace: @ws, package: pkg, pool: @c.pools.first, price: 5_200_000)

      assert_equal 5_200_000, pkg.reload.price_for(@c.pools.first)
      assert_equal 4_800_000, pkg.price_for(@c.pools.last), "hồ chưa có giá riêng thì lấy giá chung"
    end
  end

  test "giá có hiệu lực theo thời gian — tăng giá không đụng kỳ cũ" do
    with_tenant(@ws) do
      pkg = Package.create!(workspace: @ws, name: "Khoá 12 buổi", kind: "full_course", sessions: 12)
      PriceListItem.create!(workspace: @ws, package: pkg, price: 4_000_000,
                            effective_from: 1.year.ago.to_date, effective_to: 1.month.ago.to_date)
      PriceListItem.create!(workspace: @ws, package: pkg, price: 4_800_000,
                            effective_from: 1.week.ago.to_date)

      assert_equal 4_800_000, pkg.reload.price_for(nil)
      assert_equal 4_000_000, pkg.price_for(nil, on: 6.months.ago.to_date)
    end
  end

  test "hạn dùng gói: gói > khoá > cấu hình trung tâm" do
    with_tenant(@ws) do
      course = Course.create!(workspace: @ws, name: "Khoá 6 tháng", validity_days: 180)
      pkg = Package.create!(workspace: @ws, name: "Gói lẻ", kind: "per_session", course: course, sessions: 4)
      assert_equal 180, pkg.expiry_days

      pkg.update!(validity_days: 90)
      assert_equal 90, pkg.expiry_days
      assert_equal Date.current + 90, pkg.expires_on
    end
  end

  test "khuyến mãi chỉ chạy trong khoảng ngày đã đặt" do
    with_tenant(@ws) do
      promo = Promotion.create!(workspace: @ws, name: "Tặng buổi", kind: "bonus_sessions", value: 1,
                                starts_on: 1.day.from_now.to_date)
      refute promo.running?, "chưa tới ngày bắt đầu thì chưa chạy"
      promo.update!(starts_on: 1.day.ago.to_date, ends_on: Date.current)
      assert promo.running?
    end
  end
end
