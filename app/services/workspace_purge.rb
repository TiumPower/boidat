# Hard-deletes a workspace and every row that belongs to it. All tenant tables
# carry workspace_id, so we delete by that in FK-safe order (children first)
# rather than relying on ActiveRecord cascades — guaranteed no orphan / FK error.
class WorkspacePurge
  # Order matters: a table must be listed before any table it references.
  DELETE_ORDER = %w[
    audit_logs notifications push_subscriptions broadcasts
    day_pass_tickets timesheet_entries payroll_periods session_feedbacks
    payments orders attendances enrollments lessons swim_classes teacher_availabilities
    biometric_consents face_profiles students guardians households
    price_list_items promotions packages course_sessions courses
    teacher_pools teachers teacher_levels
    pool_assignments pool_holidays pool_operating_hours pools
    memberships invoices otp_challenges
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
        DELETE_ORDER.each do |table|
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
