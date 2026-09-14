require "test_helper"

# Cổng vận hành: mọi màn hình chỉ được thấy dữ liệu của hồ đang chọn.
class OpsMasterDataTest < ActionDispatch::IntegrationTest
  setup do
    @c = build_center!
    @ws = @c.workspace
    host_workspace!(@ws)
    # Học viên ở hồ thứ hai — sale không được gán hồ này.
    @other = with_tenant(@ws) do
      hh = create(:household, workspace: @ws, name: "Hộ hồ khác")
      create(:guardian, workspace: @ws, household: hh)
      create(:student, workspace: @ws, household: hh, pool: @c.pools.last, name: "Học viên hồ khác")
    end
    sign_in @c.users[:sale]
  end

  test "danh sách học viên chỉ có học viên của hồ đang chọn" do
    get "/merchant/ops/students"
    assert_response :success
    assert_match @c.student.name, response.body
    refute_match @other.name, response.body
  end

  test "mở thẳng hồ sơ học viên hồ khác thì 404, không rò rỉ" do
    get "/merchant/ops/students/#{@other.id}"
    assert_response :not_found
    refute_match @other.name, response.body
  end

  test "hộ gia đình của hồ khác không hiện trong danh sách" do
    get "/merchant/ops/households"
    assert_response :success
    refute_match "Hộ hồ khác", response.body
  end

  test "cấp lại QR làm mã cũ hết hiệu lực ngay" do
    old_token = @c.household.qr_token
    post "/merchant/ops/households/#{@c.household.id}/reissue_qr"
    assert_redirected_to "/merchant/ops/households/#{@c.household.id}"
    refute_equal old_token, with_tenant(@ws) { @c.household.reload.qr_token }

    # Mã cũ không đăng nhập được nữa.
    host! "example.com"
    get "/w/#{@ws.slug}/q/#{old_token}"
    assert_redirected_to member_login_path(workspace_slug: @ws.slug)
  end

  test "sale chuyển được sang hồ mình được gán, không chuyển sang hồ lạ" do
    post "/merchant/switch-pool/#{@c.pools.last.id}"
    assert_match "không được gán", flash[:alert]

    post "/merchant/switch-pool/#{@c.pools.first.id}"
    assert_match @c.pools.first.name, flash[:notice]
  end
end
