# Đẩy ảnh khuôn mặt sang service nhận diện. Chạy nền để phụ huynh không phải
# đợi — vector sẵn sàng sau vài giây, kịp trước buổi học đầu tiên.
class FaceEnrollJob < ApplicationJob
  queue_as :default

  def perform(face_profile_id)
    profile = ActsAsTenant.without_tenant { FaceProfile.find_by(id: face_profile_id) }
    return if profile.nil? || profile.deleted_at.present?

    ActsAsTenant.with_tenant(profile.workspace) do
      images = profile.photos.map { |p| p.download }
      return if images.empty?
      FaceClient.new.enroll(profile, images)
    end
  rescue StandardError => e
    Rails.logger.error("[face] enroll lỗi ##{face_profile_id}: #{e.class} #{e.message}")
  end
end
