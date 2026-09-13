require "digest"
require "openssl"

# Cầu nối sang service nhận diện khuôn mặt (FastAPI + InsightFace) chạy độc lập.
#
# Bảo mật: mọi request ký HMAC-SHA256 trên body + timestamp, service chỉ bind
# 127.0.0.1 nên không lộ ra Internet.
#
# Nguyên tắc vận hành: service chết KHÔNG được làm chết quầy điểm danh. Mọi lỗi
# đều trả về kết quả "không nhận diện được" để PWA rơi xuống luồng dự phòng
# (tra cứu tay / sửa trên bảng master data, FR-234).
class FaceClient
  Match = Struct.new(:student_id, :score, keyword_init: true)

  class Error < StandardError; end

  def initialize(base_url: ENV["FACE_SERVICE_URL"], secret: ENV["FACE_SERVICE_SECRET"])
    @base_url = base_url
    @secret = secret
  end

  def configured? = @base_url.present? && @secret.present?

  def healthy?
    return false unless configured?
    get("/healthz")["status"] == "ok"
  rescue StandardError
    false
  end

  # Đăng ký / cập nhật khuôn mặt của một học viên.
  def enroll(face_profile, images)
    return nil unless configured?
    payload = {
      workspace_id: face_profile.workspace_id,
      student_id: face_profile.student_id,
      images: Array(images).map { |io| Base64.strict_encode64(io) }
    }
    body = post("/v1/faces/enroll", payload)
    face_profile.update!(external_ref: body["face_id"], embedding_version: body["model"],
                         quality: body["quality"], samples_count: body["samples"].to_i)
    body
  end

  # Tra cứu một ảnh. Trả về mảng Match đã sắp xếp giảm dần theo điểm khớp.
  #
  # NGOẠI LỆ CÓ CHỦ ĐÍCH (FR-235): chỉ lọc theo workspace, KHÔNG lọc theo hồ —
  # quét ở quầy nào cũng phải tra ra. Việc chặn theo hồ nằm ở
  # StudentCheckInContext, phía sau bước nhận diện.
  def search(workspace_id:, image:, top_k: 3)
    return [] unless configured?
    body = post("/v1/faces/search", { workspace_id: workspace_id, top_k: top_k,
                                      image: Base64.strict_encode64(image) })
    Array(body["matches"]).map { |m| Match.new(student_id: m["student_id"], score: m["score"].to_f) }
  rescue StandardError => e
    Rails.logger.error("[face] search lỗi: #{e.class} #{e.message}")
    []
  end

  def delete(face_profile)
    return unless configured? && face_profile.external_ref.present?
    request(:delete, "/v1/faces/#{face_profile.student_id}",
            { workspace_id: face_profile.workspace_id })
  rescue StandardError => e
    Rails.logger.error("[face] delete lỗi: #{e.class} #{e.message}")
    nil
  end

  private

  def get(path) = request(:get, path, nil)
  def post(path, payload) = request(:post, path, payload)

  def request(method, path, payload)
    body = payload ? JSON.generate(payload) : ""
    timestamp = Time.now.to_i.to_s
    response = connection.public_send(method, path) do |req|
      req.headers["Content-Type"] = "application/json"
      req.headers["X-Timestamp"] = timestamp
      req.headers["X-Signature"] = sign(timestamp, body)
      req.body = body if payload
    end
    raise Error, "HTTP #{response.status}" unless response.success?
    response.body.is_a?(Hash) ? response.body : JSON.parse(response.body.presence || "{}")
  end

  def sign(timestamp, body)
    OpenSSL::HMAC.hexdigest("SHA256", @secret.to_s, "#{timestamp}.#{body}")
  end

  def connection
    @connection ||= Faraday.new(url: @base_url) do |f|
      f.request :retry, max: 1, interval: 0.2
      f.response :json, content_type: /json/
      f.options.timeout = 8
      f.options.open_timeout = 2
    end
  end
end
