require "test_helper"

# FaceClient là ranh giới giữa Rails và service nhận diện. Điều quan trọng nhất
# cần khoá bằng test: service chết thì quầy vẫn chạy được.
class FaceClientTest < ActiveSupport::TestCase
  setup do
    @c = build_center!
    @ws = @c.workspace
  end

  test "ký request giống hệt cách service Python kiểm tra" do
    client = FaceClient.new(base_url: "http://127.0.0.1:8008", secret: "s3cret")
    signature = client.send(:sign, "1700000000", '{"a":1}')
    expected = OpenSSL::HMAC.hexdigest("SHA256", "s3cret", '1700000000.{"a":1}')
    assert_equal expected, signature
  end

  test "chưa cấu hình thì không gọi ra ngoài và trả rỗng" do
    client = FaceClient.new(base_url: nil, secret: nil)
    refute client.configured?
    assert_equal [], client.search(workspace_id: @ws.id, image: "x")
    refute client.healthy?
  end

  test "service lỗi thì search trả rỗng chứ không ném exception" do
    client = FaceClient.new(base_url: "http://127.0.0.1:1", secret: "s")
    assert_equal [], client.search(workspace_id: @ws.id, image: "x"),
                 "quầy điểm danh không được chết vì service nhận diện chết"
  end

  test "tỷ lệ quét lỗi cao thì gắn cờ đề nghị chụp lại ảnh (OQ-01)" do
    with_tenant(@ws) do
      profile = FaceProfile.create!(workspace: @ws, student: @c.student, captured_at: 1.year.ago)
      8.times { profile.record_scan!(success: true) }
      refute profile.reload.recapture_flag?, "quét tốt thì không gắn cờ"

      4.times { profile.record_scan!(success: false) }
      assert profile.reload.recapture_flag?, "vượt ngưỡng lỗi thì phải nhắc chụp lại"
    end
  end

  test "xoá mềm hồ sơ khuôn mặt thì học viên coi như chưa đăng ký" do
    with_tenant(@ws) do
      profile = FaceProfile.create!(workspace: @ws, student: @c.student, external_ref: "1:1")
      assert @c.student.reload.face_registered?
      profile.soft_delete!
      refute @c.student.reload.face_registered?
      assert_nil profile.reload.external_ref
    end
  end
end
