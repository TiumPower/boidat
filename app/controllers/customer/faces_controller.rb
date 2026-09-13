module Customer
  # Đăng ký ảnh khuôn mặt cho từng học viên + đồng ý xử lý dữ liệu sinh trắc học
  # (FR-402).
  #
  # Khách đã chốt: KHÔNG làm màn hình đồng ý riêng — checkbox nằm ngay tại bước
  # phụ huynh submit ảnh lần đầu. Không tích thì không submit được. Hệ thống lưu
  # lại ai tích, lúc nào, cho học viên nào, phiên bản điều khoản nào.
  class FacesController < BaseController
    before_action :require_guardian!

    def index
      @students = household_students.includes(:face_profile)
      @terms_version = BiometricConsent::CURRENT_TERMS_VERSION
    end

    def create
      student = household_students.find(params[:student_id])
      photo = params[:photo]

      unless params[:consent] == "1"
        return redirect_to(member_faces_path, alert: "Cần tích ô đồng ý xử lý dữ liệu sinh trắc học.")
      end
      return redirect_to(member_faces_path, alert: "Chưa chọn ảnh.") if photo.blank?

      profile = FaceProfile.find_or_initialize_by(workspace: current_workspace, student: student)
      profile.assign_attributes(captured_at: Time.current, deleted_at: nil, recapture_flag: false,
                                fail_count: 0, scan_count: 0)
      profile.save!
      profile.photos.attach(photo)

      BiometricConsent.record!(student: student, guardian: current_guardian, request: request)
      # Đẩy vector sang service nhận diện chạy nền — quầy dùng được ngay sau vài giây.
      FaceEnrollJob.perform_later(profile.id)

      redirect_to member_faces_path, notice: "Đã lưu ảnh của #{student.short_name}."
    end

    # Quyền yêu cầu xoá dữ liệu sinh trắc học (Nghị định 13/2023/NĐ-CP).
    def destroy
      student = household_students.find(params[:student_id])
      profile = student.face_profile
      if profile
        FaceClient.new.delete(profile) if profile.external_ref.present?
        profile.soft_delete!
        student.biometric_consents.active.each(&:revoke!)
        AuditLog.record!(action: "destroy", entity: profile, pool: student.pool,
                         summary: "Phụ huynh yêu cầu xoá dữ liệu khuôn mặt của #{student.name}",
                         request: request)
      end
      redirect_to member_faces_path,
                  notice: "Đã xoá dữ liệu khuôn mặt của #{student.short_name}. " \
                          "Em sẽ cần điểm danh thủ công cho tới khi chụp lại."
    end
  end
end
