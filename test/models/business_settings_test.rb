require "test_helper"

# Các quy tắc nghiệp vụ còn tranh luận với khách đều phải đọc từ cấu hình, không
# hard-code. Test này khoá lại default và chứng minh đổi cấu hình là đổi hành vi.
class BusinessSettingsTest < ActiveSupport::TestCase
  setup { @ws = create(:workspace) }

  test "bảng công theo BR-02 và OQ-05 đã chốt: 0.5 công mỗi học viên" do
    assert_equal 0.5, @ws.credits_for(1)
    assert_equal 1.0, @ws.credits_for(2)
    assert_equal 1.5, @ws.credits_for(3)
    assert_equal 2.0, @ws.credits_for(4), "OQ-05 đã chốt: lớp 1:4 = 2.0 công, không đặt trần"
    assert_equal 0.0, @ws.credits_for(0), "không ai đến thì không có công"
  end

  test "sĩ số vượt bảng thì lấy mức cao nhất — đặt trần chứ không ngoại suy" do
    assert_equal 2.0, @ws.credits_for(7)
  end

  test "khách đổi chính sách sang đặt trần 1.5 công thì không phải sửa code" do
    @ws.update_business_settings!("credit_table" => { "1" => 0.5, "2" => 1.0, "3" => 1.5, "4" => 1.5 })
    assert_equal 1.5, @ws.reload.credits_for(4)
  end

  test "OQ-25 đã chốt: khoá có đủ 12 buổi học, buổi 12 KHÔNG phải buổi thi" do
    assert_equal 12, @ws.course_session_count
    assert_equal 11, @ws.graduation_at_session, "vào danh sách chuẩn bị thi ở buổi 11"
    assert_nil @ws.exam_session_index, "kỳ thi xếp riêng, không buổi nào trong khoá là buổi thi"
    refute @ws.exam_deducts_session?, "thi ngoài gói nên không trừ buổi"
  end

  test "trung tâm nào muốn gộp buổi thi vào khoá thì chỉ cần khai số buổi" do
    @ws.update_business_settings!("exam_session_index" => 12)
    assert_equal 12, @ws.reload.exam_session_index
  end

  test "vắng không báo thì không trừ buổi (BR-12)" do
    refute @ws.no_show_deducts?
  end

  test "OQ-06 đã chốt: công tính theo sĩ số CÓ MẶT" do
    refute @ws.credit_basis_registered?, "học viên vắng thì không tính công cho suất đó"
    @ws.update_business_settings!("credit_basis" => "registered")
    assert @ws.reload.credit_basis_registered?
  end

  test "nhận xét không chặn lương (OQ-22)" do
    refute @ws.feedback_blocks_payroll?
  end
end
