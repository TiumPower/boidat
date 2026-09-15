# Hard-deletes a workspace and every row that belongs to it. All tenant tables
# carry workspace_id, so we delete by that in FK-safe order (children first)
# rather than relying on ActiveRecord cascades — guaranteed no orphan / FK error.
class WorkspacePurge
  # Order matters: a table must be listed before any table it references.
  DELETE_ORDER = %w[
    audit_logs notifications push_subscriptions broadcasts
    makeup_requests schedule_runs leave_requests
    contracts messages conversations
    day_pass_tickets timesheet_entries payroll_periods session_feedbacks
    payments orders attendances enrollments lessons swim_classes teacher_availabilities
    biometric_consents face_profiles students guardians households
    price_list_items promotions packages course_sessions courses
    teacher_pools teachers teacher_levels
    pool_assignments pool_holidays pool_operating_hours pools
    memberships invoices
  ].freeze

  def self.call(workspace)
    ActsAsTenant.without_tenant do
      ApplicationRecord.transaction do
        wid = workspace.id
        # Purge Active Storage first so blobs/files don't orphan.
        purge_attachments("Workspace", [wid])
        purge_attachments("User", Membership.where(workspace_id: wid).pluck(:user_id))
        purge_attachments("FaceProfile", FaceProfile.where(workspace_id: wid).pluck(:id))

        conn = ApplicationRecord.connection
        # Danh sách này trôi theo schema. Một bảng bị xoá đi mà quên gỡ khỏi đây
        # sẽ ném PG::UndefinedTable giữa transaction và làm hỏng hẳn việc xoá
        # trung tâm — đúng chuyện vừa xảy ra khi bỏ `otp_challenges`. Bỏ qua
        # bảng không còn tồn tại, nhưng ghi log để không âm thầm quên.
        DELETE_ORDER.each do |table|
          unless conn.table_exists?(table)
            Rails.logger.warn("[WorkspacePurge] bỏ qua bảng không còn tồn tại: #{table}")
            next
          end
          conn.exec_delete("DELETE FROM #{table} WHERE workspace_id = #{wid.to_i}", "WorkspacePurge")
        end
        workspace.destroy!
      end
    end
  end

  def self.purge_attachments(record_type, ids)
    ActiveStorage::Attachment.where(record_type: record_type, record_id: ids).find_each(&:purge)
  end
end
