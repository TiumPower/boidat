require "test_helper"

# Các quy tắc nghiệp vụ còn tranh luận với khách đều phải đọc từ cấu hình, không
# hard-code. Test này khoá lại default và chứng minh đổi cấu hình là đổi hành vi.
class BusinessSettingsTest < ActiveSupport::TestCase
  setup { @ws = create(:workspace) }

  test "bảng công mặc định theo BR-02 và OQ-05" do
    assert_equal 0.5, @ws.credits_for(1)
    assert_equal 1.0, @ws.credits_for(2)
    assert_equal 1.5, @ws.credits_for(3)
    assert_equal 2.0, @ws.credits_for(4), "OQ-05 mặc định suy tuyến tính cho lớp 1:4"
    assert_equal 0.0, @ws.credits_for(0)
  end

  test "sĩ số vượt bảng thì lấy mức cao nhất — đặt trần chứ không ngoại suy" do
    assert_equal 2.0, @ws.credits_for(7)
  end

  test "khách đổi chính sách sang đặt trần 1.5 công thì không phải sửa code" do
    @ws.update_business_settings!("credit_table" => { "1" => 0.5, "2" => 1.0, "3" => 1.5, "4" => 1.5 })
    assert_equal 1.5, @ws.reload.credits_for(4)
  end

  test "vòng đời khoá học khớp OQ-25: 12 buổi, thi ở buổi 12, xét tốt nghiệp ở buổi 11" do
    assert_equal 12, @ws.course_session_count
    assert_equal 11, @ws.graduation_at_session
    assert_equal 12, @ws.exam_session_index
    refute @ws.exam_deducts_session?, "buổi thi không trừ khỏi gói"
    assert @ws.exam_pays_credit?,     "buổi thi vẫn tính công cho giáo viên"
  end

  test "vắng không báo thì không trừ buổi (BR-12)" do
    refute @ws.no_show_deducts?
  end

  test "công tính theo sĩ số đăng ký (OQ-06 default)" do
    assert @ws.credit_basis_registered?
    @ws.update_business_settings!("credit_basis" => "present")
    refute @ws.reload.credit_basis_registered?
  end

  test "nhận xét không chặn lương (OQ-22)" do
    refute @ws.feedback_blocks_payroll?
  end
end
