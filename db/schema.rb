# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[7.2].define(version: 2026_09_15_110432) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "active_storage_attachments", force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.string "key", null: false
    t.string "filename", null: false
    t.string "content_type"
    t.text "metadata"
    t.string "service_name", null: false
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.datetime "created_at", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "admin_users", force: :cascade do |t|
    t.string "name", default: "", null: false
    t.string "role", default: "operator", null: false
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.integer "sign_in_count", default: 0, null: false
    t.datetime "current_sign_in_at"
    t.datetime "last_sign_in_at"
    t.string "current_sign_in_ip"
    t.string "last_sign_in_ip"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_admin_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_admin_users_on_reset_password_token", unique: true
  end

  create_table "attendances", force: :cascade do |t|
    t.bigint "workspace_id", null: false
    t.bigint "pool_id", null: false
    t.bigint "lesson_id", null: false
    t.bigint "student_id", null: false
    t.bigint "enrollment_id"
    t.bigint "actor_id"
    t.string "status", default: "present", null: false
    t.string "method", default: "manual", null: false
    t.float "face_score"
    t.boolean "deducted", default: false, null: false
    t.datetime "checked_in_at"
    t.string "note"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["actor_id"], name: "index_attendances_on_actor_id"
    t.index ["enrollment_id"], name: "index_attendances_on_enrollment_id"
    t.index ["lesson_id", "student_id"], name: "index_attendances_on_lesson_id_and_student_id", unique: true
    t.index ["lesson_id"], name: "index_attendances_on_lesson_id"
    t.index ["pool_id"], name: "index_attendances_on_pool_id"
    t.index ["student_id"], name: "index_attendances_on_student_id"
    t.index ["workspace_id", "pool_id", "checked_in_at"], name: "idx_on_workspace_id_pool_id_checked_in_at_4532ff50f4"
    t.index ["workspace_id"], name: "index_attendances_on_workspace_id"
  end

  create_table "audit_logs", force: :cascade do |t|
    t.bigint "workspace_id", null: false
    t.bigint "pool_id"
    t.bigint "user_id"
    t.string "actor_label"
    t.string "action", null: false
    t.string "entity_type", null: false
    t.bigint "entity_id"
    t.string "summary"
    t.jsonb "changes_before", default: {}, null: false
    t.jsonb "changes_after", default: {}, null: false
    t.string "ip"
    t.string "user_agent"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["entity_type", "entity_id"], name: "index_audit_logs_on_entity_type_and_entity_id"
    t.index ["pool_id"], name: "index_audit_logs_on_pool_id"
    t.index ["user_id"], name: "index_audit_logs_on_user_id"
    t.index ["workspace_id", "created_at"], name: "index_audit_logs_on_workspace_id_and_created_at"
    t.index ["workspace_id", "user_id", "created_at"], name: "index_audit_logs_on_workspace_user_time"
    t.index ["workspace_id"], name: "index_audit_logs_on_workspace_id"
  end

  create_table "biometric_consents", force: :cascade do |t|
    t.bigint "workspace_id", null: false
    t.bigint "student_id", null: false
    t.bigint "guardian_id"
    t.string "terms_version", null: false
    t.string "ip"
    t.string "user_agent"
    t.datetime "consented_at", null: false
    t.datetime "revoked_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["guardian_id"], name: "index_biometric_consents_on_guardian_id"
    t.index ["student_id"], name: "index_biometric_consents_on_student_id"
    t.index ["workspace_id"], name: "index_biometric_consents_on_workspace_id"
  end

  create_table "broadcasts", force: :cascade do |t|
    t.bigint "workspace_id", null: false
    t.bigint "pool_id"
    t.bigint "created_by_id"
    t.string "segment_key", default: "all", null: false
    t.string "title", null: false
    t.text "body"
    t.integer "sent_count", default: 0, null: false
    t.datetime "scheduled_at"
    t.datetime "sent_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["created_by_id"], name: "index_broadcasts_on_created_by_id"
    t.index ["pool_id"], name: "index_broadcasts_on_pool_id"
    t.index ["workspace_id"], name: "index_broadcasts_on_workspace_id"
  end

  create_table "contracts", force: :cascade do |t|
    t.bigint "workspace_id", null: false
    t.bigint "pool_id", null: false
    t.bigint "enrollment_id", null: false
    t.bigint "household_id", null: false
    t.bigint "signed_by_id"
    t.string "number", null: false
    t.string "status", default: "draft", null: false
    t.string "guardian_name"
    t.datetime "signed_at"
    t.string "sha256"
    t.string "ip"
    t.string "user_agent"
    t.jsonb "snapshot", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["enrollment_id"], name: "index_contracts_on_enrollment_id"
    t.index ["household_id"], name: "index_contracts_on_household_id"
    t.index ["number"], name: "index_contracts_on_number", unique: true
    t.index ["pool_id"], name: "index_contracts_on_pool_id"
    t.index ["signed_by_id"], name: "index_contracts_on_signed_by_id"
    t.index ["workspace_id", "status"], name: "index_contracts_on_workspace_id_and_status"
    t.index ["workspace_id"], name: "index_contracts_on_workspace_id"
  end

  create_table "conversations", force: :cascade do |t|
    t.bigint "workspace_id", null: false
    t.bigint "pool_id", null: false
    t.bigint "household_id", null: false
    t.integer "staff_unread", default: 0, null: false
    t.integer "guardian_unread", default: 0, null: false
    t.datetime "last_message_at"
    t.string "last_preview"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["household_id"], name: "index_conversations_on_household_id"
    t.index ["pool_id", "household_id"], name: "index_conversations_on_pool_id_and_household_id", unique: true
    t.index ["pool_id"], name: "index_conversations_on_pool_id"
    t.index ["workspace_id", "last_message_at"], name: "index_conversations_on_workspace_id_and_last_message_at"
    t.index ["workspace_id"], name: "index_conversations_on_workspace_id"
  end

  create_table "course_sessions", force: :cascade do |t|
    t.bigint "workspace_id", null: false
    t.bigint "course_id", null: false
    t.integer "position", null: false
    t.string "title", null: false
    t.text "content"
    t.string "goal"
    t.boolean "exam", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["course_id", "position"], name: "index_course_sessions_on_course_id_and_position", unique: true
    t.index ["course_id"], name: "index_course_sessions_on_course_id"
    t.index ["workspace_id"], name: "index_course_sessions_on_workspace_id"
  end

  create_table "courses", force: :cascade do |t|
    t.bigint "workspace_id", null: false
    t.string "name", null: false
    t.string "code"
    t.text "description"
    t.string "audience", default: "child", null: false
    t.string "status", default: "active", null: false
    t.integer "position", default: 0, null: false
    t.integer "sessions_count"
    t.integer "graduation_at_session"
    t.integer "exam_session_index"
    t.integer "validity_days"
    t.jsonb "class_types", default: [1, 2, 3, 4], null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["workspace_id", "name"], name: "index_courses_on_workspace_id_and_name"
    t.index ["workspace_id"], name: "index_courses_on_workspace_id"
  end

  create_table "day_pass_tickets", force: :cascade do |t|
    t.bigint "workspace_id", null: false
    t.bigint "pool_id", null: false
    t.bigint "order_id"
    t.bigint "issued_by_id"
    t.string "code", null: false
    t.string "guest_name"
    t.string "guest_phone"
    t.integer "quantity", default: 1, null: false
    t.date "valid_on", null: false
    t.datetime "used_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["code"], name: "index_day_pass_tickets_on_code", unique: true
    t.index ["issued_by_id"], name: "index_day_pass_tickets_on_issued_by_id"
    t.index ["order_id"], name: "index_day_pass_tickets_on_order_id"
    t.index ["pool_id"], name: "index_day_pass_tickets_on_pool_id"
    t.index ["workspace_id", "pool_id", "valid_on"], name: "idx_on_workspace_id_pool_id_valid_on_4fa3c154c1"
    t.index ["workspace_id"], name: "index_day_pass_tickets_on_workspace_id"
  end

  create_table "enrollments", force: :cascade do |t|
    t.bigint "workspace_id", null: false
    t.bigint "pool_id", null: false
    t.bigint "student_id", null: false
    t.bigint "swim_class_id", null: false
    t.bigint "package_id"
    t.integer "sessions_total", default: 0, null: false
    t.integer "sessions_used", default: 0, null: false
    t.integer "bonus_sessions", default: 0, null: false
    t.date "starts_on"
    t.date "expires_on"
    t.string "status", default: "active", null: false
    t.string "customer_type", default: "new", null: false
    t.datetime "exam_eligible_at"
    t.string "exam_result"
    t.date "exam_date"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["package_id"], name: "index_enrollments_on_package_id"
    t.index ["pool_id"], name: "index_enrollments_on_pool_id"
    t.index ["student_id", "swim_class_id"], name: "index_enrollments_on_student_id_and_swim_class_id", unique: true
    t.index ["student_id"], name: "index_enrollments_on_student_id"
    t.index ["swim_class_id"], name: "index_enrollments_on_swim_class_id"
    t.index ["workspace_id", "status"], name: "index_enrollments_on_workspace_id_and_status"
    t.index ["workspace_id"], name: "index_enrollments_on_workspace_id"
  end

  create_table "face_profiles", force: :cascade do |t|
    t.bigint "workspace_id", null: false
    t.bigint "student_id", null: false
    t.string "external_ref"
    t.string "embedding_version"
    t.float "quality"
    t.integer "samples_count", default: 0, null: false
    t.datetime "captured_at"
    t.boolean "recapture_flag", default: false, null: false
    t.integer "fail_count", default: 0, null: false
    t.integer "scan_count", default: 0, null: false
    t.datetime "deleted_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["student_id"], name: "index_face_profiles_on_student_id"
    t.index ["workspace_id", "student_id"], name: "index_face_profiles_on_workspace_id_and_student_id", unique: true
    t.index ["workspace_id"], name: "index_face_profiles_on_workspace_id"
  end

  create_table "friendly_id_slugs", force: :cascade do |t|
    t.string "slug", null: false
    t.integer "sluggable_id", null: false
    t.string "sluggable_type", limit: 50
    t.string "scope"
    t.datetime "created_at"
    t.index ["slug", "sluggable_type", "scope"], name: "index_friendly_id_slugs_on_slug_and_sluggable_type_and_scope", unique: true
    t.index ["slug", "sluggable_type"], name: "index_friendly_id_slugs_on_slug_and_sluggable_type"
    t.index ["sluggable_type", "sluggable_id"], name: "index_friendly_id_slugs_on_sluggable_type_and_sluggable_id"
  end

  create_table "guardians", force: :cascade do |t|
    t.bigint "workspace_id", null: false
    t.bigint "household_id", null: false
    t.string "name", null: false
    t.string "phone"
    t.string "email"
    t.string "relation"
    t.string "role", default: "owner", null: false
    t.boolean "is_student", default: false, null: false
    t.datetime "last_seen_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "qr_token", null: false
    t.datetime "qr_issued_at"
    t.datetime "qr_revoked_at"
    t.index ["household_id"], name: "index_guardians_on_household_id"
    t.index ["qr_token"], name: "index_guardians_on_qr_token", unique: true
    t.index ["workspace_id", "phone"], name: "index_guardians_on_workspace_id_and_phone"
    t.index ["workspace_id"], name: "index_guardians_on_workspace_id"
  end

  create_table "households", force: :cascade do |t|
    t.bigint "workspace_id", null: false
    t.string "name", null: false
    t.string "kind", default: "family", null: false
    t.string "qr_token", null: false
    t.datetime "qr_issued_at"
    t.datetime "qr_revoked_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["qr_token"], name: "index_households_on_qr_token", unique: true
    t.index ["workspace_id", "name"], name: "index_households_on_workspace_id_and_name"
    t.index ["workspace_id"], name: "index_households_on_workspace_id"
  end

  create_table "invoices", force: :cascade do |t|
    t.bigint "workspace_id", null: false
    t.string "plan", null: false
    t.integer "amount", default: 0, null: false
    t.string "status", default: "pending", null: false
    t.date "period_start", null: false
    t.date "period_end", null: false
    t.bigint "payos_order_code"
    t.string "checkout_url"
    t.datetime "paid_at"
    t.jsonb "gateway_response", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["payos_order_code"], name: "index_invoices_on_payos_order_code", unique: true, where: "(payos_order_code IS NOT NULL)"
    t.index ["workspace_id", "status"], name: "index_invoices_on_workspace_id_and_status"
    t.index ["workspace_id"], name: "index_invoices_on_workspace_id"
  end

  create_table "leave_requests", force: :cascade do |t|
    t.bigint "workspace_id", null: false
    t.bigint "teacher_id", null: false
    t.bigint "reviewed_by_id"
    t.bigint "lesson_ids", default: [], null: false, array: true
    t.text "reason"
    t.string "status", default: "pending", null: false
    t.text "review_note"
    t.datetime "submitted_at"
    t.datetime "reviewed_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["lesson_ids"], name: "index_leave_requests_on_lesson_ids", using: :gin
    t.index ["reviewed_by_id"], name: "index_leave_requests_on_reviewed_by_id"
    t.index ["teacher_id"], name: "index_leave_requests_on_teacher_id"
    t.index ["workspace_id", "status"], name: "index_leave_requests_on_workspace_id_and_status"
    t.index ["workspace_id"], name: "index_leave_requests_on_workspace_id"
  end

  create_table "lessons", force: :cascade do |t|
    t.bigint "workspace_id", null: false
    t.bigint "pool_id", null: false
    t.bigint "teacher_id", null: false
    t.bigint "swim_class_id", null: false
    t.date "date", null: false
    t.integer "start_hour", null: false
    t.integer "session_index"
    t.string "status", default: "scheduled", null: false
    t.string "cancel_reason"
    t.text "content_override"
    t.boolean "exam", default: false, null: false
    t.datetime "completed_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["pool_id"], name: "index_lessons_on_pool_id"
    t.index ["swim_class_id", "date"], name: "index_lessons_on_swim_class_id_and_date"
    t.index ["swim_class_id", "session_index"], name: "index_lessons_on_swim_class_id_and_session_index"
    t.index ["swim_class_id"], name: "index_lessons_on_swim_class_id"
    t.index ["teacher_id", "date", "start_hour"], name: "index_lessons_on_teacher_id_and_date_and_start_hour"
    t.index ["teacher_id"], name: "index_lessons_on_teacher_id"
    t.index ["workspace_id", "pool_id", "date"], name: "index_lessons_on_workspace_id_and_pool_id_and_date"
    t.index ["workspace_id"], name: "index_lessons_on_workspace_id"
  end

  create_table "makeup_requests", force: :cascade do |t|
    t.bigint "workspace_id", null: false
    t.bigint "pool_id", null: false
    t.bigint "enrollment_id", null: false
    t.bigint "student_id", null: false
    t.bigint "from_lesson_id"
    t.bigint "to_lesson_id"
    t.bigint "leave_request_id"
    t.bigint "decided_by_id"
    t.string "origin", default: "guardian_absence", null: false
    t.string "choice"
    t.string "status", default: "pending", null: false
    t.text "reason"
    t.datetime "decided_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["decided_by_id"], name: "index_makeup_requests_on_decided_by_id"
    t.index ["enrollment_id", "from_lesson_id"], name: "index_makeup_requests_on_enrollment_id_and_from_lesson_id"
    t.index ["enrollment_id"], name: "index_makeup_requests_on_enrollment_id"
    t.index ["from_lesson_id"], name: "index_makeup_requests_on_from_lesson_id"
    t.index ["leave_request_id"], name: "index_makeup_requests_on_leave_request_id"
    t.index ["pool_id"], name: "index_makeup_requests_on_pool_id"
    t.index ["student_id"], name: "index_makeup_requests_on_student_id"
    t.index ["to_lesson_id"], name: "index_makeup_requests_on_to_lesson_id"
    t.index ["workspace_id", "status"], name: "index_makeup_requests_on_workspace_id_and_status"
    t.index ["workspace_id"], name: "index_makeup_requests_on_workspace_id"
  end

  create_table "memberships", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "workspace_id", null: false
    t.string "role", default: "sale", null: false
    t.string "status", default: "active", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id", "workspace_id"], name: "index_memberships_on_user_id_and_workspace_id", unique: true
    t.index ["user_id"], name: "index_memberships_on_user_id"
    t.index ["workspace_id", "role"], name: "index_memberships_on_workspace_id_and_role"
    t.index ["workspace_id"], name: "index_memberships_on_workspace_id"
  end

  create_table "messages", force: :cascade do |t|
    t.bigint "workspace_id", null: false
    t.bigint "conversation_id", null: false
    t.bigint "user_id"
    t.bigint "guardian_id"
    t.string "sender_kind", default: "staff", null: false
    t.text "body"
    t.datetime "read_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["conversation_id", "created_at"], name: "index_messages_on_conversation_id_and_created_at"
    t.index ["conversation_id"], name: "index_messages_on_conversation_id"
    t.index ["guardian_id"], name: "index_messages_on_guardian_id"
    t.index ["user_id"], name: "index_messages_on_user_id"
    t.index ["workspace_id"], name: "index_messages_on_workspace_id"
  end

  create_table "notifications", force: :cascade do |t|
    t.bigint "workspace_id", null: false
    t.bigint "broadcast_id"
    t.string "recipient_type", null: false
    t.bigint "recipient_id", null: false
    t.string "title", null: false
    t.text "body"
    t.string "kind", default: "system", null: false
    t.string "icon"
    t.string "deep_link"
    t.string "subject_type"
    t.bigint "subject_id"
    t.boolean "requires_ack", default: false, null: false
    t.datetime "read_at"
    t.datetime "acknowledged_at"
    t.string "ack_choice"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["broadcast_id"], name: "index_notifications_on_broadcast_id"
    t.index ["recipient_type", "recipient_id", "read_at"], name: "index_notifications_on_recipient_and_read"
    t.index ["recipient_type", "recipient_id"], name: "index_notifications_on_recipient"
    t.index ["subject_type", "subject_id"], name: "index_notifications_on_subject"
    t.index ["workspace_id", "requires_ack", "acknowledged_at"], name: "index_notifications_on_ack_tracking"
    t.index ["workspace_id"], name: "index_notifications_on_workspace_id"
  end

  create_table "orders", force: :cascade do |t|
    t.bigint "workspace_id", null: false
    t.bigint "pool_id", null: false
    t.bigint "household_id"
    t.bigint "student_id"
    t.bigint "enrollment_id"
    t.bigint "package_id"
    t.bigint "sale_id"
    t.string "code", null: false
    t.integer "amount", default: 0, null: false
    t.integer "discount", default: 0, null: false
    t.string "status", default: "unpaid", null: false
    t.string "kind", default: "course", null: false
    t.string "customer_type", default: "new", null: false
    t.bigint "payos_order_code"
    t.string "checkout_url"
    t.datetime "paid_at"
    t.jsonb "gateway_response", default: {}, null: false
    t.text "note"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["code"], name: "index_orders_on_code", unique: true
    t.index ["enrollment_id"], name: "index_orders_on_enrollment_id"
    t.index ["household_id"], name: "index_orders_on_household_id"
    t.index ["package_id"], name: "index_orders_on_package_id"
    t.index ["payos_order_code"], name: "index_orders_on_payos_order_code", unique: true, where: "(payos_order_code IS NOT NULL)"
    t.index ["pool_id"], name: "index_orders_on_pool_id"
    t.index ["sale_id"], name: "index_orders_on_sale_id"
    t.index ["student_id"], name: "index_orders_on_student_id"
    t.index ["workspace_id", "pool_id", "status"], name: "index_orders_on_workspace_id_and_pool_id_and_status"
    t.index ["workspace_id"], name: "index_orders_on_workspace_id"
  end

  create_table "packages", force: :cascade do |t|
    t.bigint "workspace_id", null: false
    t.bigint "course_id"
    t.string "name", null: false
    t.string "kind", default: "full_course", null: false
    t.integer "class_type"
    t.integer "sessions"
    t.integer "validity_days"
    t.string "status", default: "active", null: false
    t.text "description"
    t.integer "position", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["course_id"], name: "index_packages_on_course_id"
    t.index ["workspace_id", "kind"], name: "index_packages_on_workspace_id_and_kind"
    t.index ["workspace_id"], name: "index_packages_on_workspace_id"
  end

  create_table "payments", force: :cascade do |t|
    t.bigint "workspace_id", null: false
    t.bigint "order_id", null: false
    t.bigint "recorded_by_id"
    t.integer "amount", default: 0, null: false
    t.string "method", default: "payos", null: false
    t.datetime "paid_at", null: false
    t.string "reference"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["order_id"], name: "index_payments_on_order_id"
    t.index ["recorded_by_id"], name: "index_payments_on_recorded_by_id"
    t.index ["workspace_id", "paid_at"], name: "index_payments_on_workspace_id_and_paid_at"
    t.index ["workspace_id"], name: "index_payments_on_workspace_id"
  end

  create_table "payroll_periods", force: :cascade do |t|
    t.bigint "workspace_id", null: false
    t.bigint "pool_id"
    t.bigint "locked_by_id"
    t.date "starts_on", null: false
    t.date "ends_on", null: false
    t.datetime "locked_at"
    t.decimal "total_credits", precision: 8, scale: 2, default: "0.0", null: false
    t.integer "total_amount", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["locked_by_id"], name: "index_payroll_periods_on_locked_by_id"
    t.index ["pool_id"], name: "index_payroll_periods_on_pool_id"
    t.index ["workspace_id", "pool_id", "starts_on"], name: "index_payroll_on_pool_start"
    t.index ["workspace_id"], name: "index_payroll_periods_on_workspace_id"
  end

  create_table "plans", force: :cascade do |t|
    t.string "key", null: false
    t.string "name", null: false
    t.integer "price", default: 0, null: false
    t.integer "position", default: 0, null: false
    t.integer "max_pools"
    t.integer "max_students"
    t.integer "max_teachers"
    t.boolean "allow_custom_domain", default: false, null: false
    t.boolean "allow_face_recognition", default: true, null: false
    t.boolean "allow_auto_scheduler", default: true, null: false
    t.boolean "allow_chat", default: true, null: false
    t.jsonb "features", default: [], null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_plans_on_key", unique: true
  end

  create_table "pool_assignments", force: :cascade do |t|
    t.bigint "workspace_id", null: false
    t.bigint "pool_id", null: false
    t.bigint "user_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["pool_id", "user_id"], name: "index_pool_assignments_on_pool_id_and_user_id", unique: true
    t.index ["pool_id"], name: "index_pool_assignments_on_pool_id"
    t.index ["user_id"], name: "index_pool_assignments_on_user_id"
    t.index ["workspace_id"], name: "index_pool_assignments_on_workspace_id"
  end

  create_table "pool_holidays", force: :cascade do |t|
    t.bigint "workspace_id", null: false
    t.bigint "pool_id", null: false
    t.date "date", null: false
    t.string "reason"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["pool_id", "date"], name: "index_pool_holidays_on_pool_id_and_date", unique: true
    t.index ["pool_id"], name: "index_pool_holidays_on_pool_id"
    t.index ["workspace_id"], name: "index_pool_holidays_on_workspace_id"
  end

  create_table "pool_operating_hours", force: :cascade do |t|
    t.bigint "workspace_id", null: false
    t.bigint "pool_id", null: false
    t.integer "weekday", null: false
    t.time "opens_at"
    t.time "closes_at"
    t.boolean "closed", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["pool_id", "weekday"], name: "index_pool_operating_hours_on_pool_id_and_weekday", unique: true
    t.index ["pool_id"], name: "index_pool_operating_hours_on_pool_id"
    t.index ["workspace_id"], name: "index_pool_operating_hours_on_workspace_id"
  end

  create_table "pools", force: :cascade do |t|
    t.bigint "workspace_id", null: false
    t.string "name", null: false
    t.string "code"
    t.string "address"
    t.string "phone"
    t.string "status", default: "active", null: false
    t.integer "position", default: 0, null: false
    t.jsonb "settings", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["workspace_id", "name"], name: "index_pools_on_workspace_id_and_name"
    t.index ["workspace_id"], name: "index_pools_on_workspace_id"
  end

  create_table "price_list_items", force: :cascade do |t|
    t.bigint "workspace_id", null: false
    t.bigint "package_id", null: false
    t.bigint "pool_id"
    t.integer "price", default: 0, null: false
    t.date "effective_from"
    t.date "effective_to"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["package_id", "pool_id", "effective_from"], name: "index_price_items_on_package_pool_from"
    t.index ["package_id"], name: "index_price_list_items_on_package_id"
    t.index ["pool_id"], name: "index_price_list_items_on_pool_id"
    t.index ["workspace_id"], name: "index_price_list_items_on_workspace_id"
  end

  create_table "promotions", force: :cascade do |t|
    t.bigint "workspace_id", null: false
    t.bigint "pool_id"
    t.string "name", null: false
    t.string "kind", default: "bonus_sessions", null: false
    t.integer "value", default: 0, null: false
    t.text "condition_note"
    t.integer "stock"
    t.string "status", default: "active", null: false
    t.date "starts_on"
    t.date "ends_on"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["pool_id"], name: "index_promotions_on_pool_id"
    t.index ["workspace_id", "status"], name: "index_promotions_on_workspace_id_and_status"
    t.index ["workspace_id"], name: "index_promotions_on_workspace_id"
  end

  create_table "push_subscriptions", force: :cascade do |t|
    t.bigint "workspace_id", null: false
    t.bigint "guardian_id"
    t.bigint "user_id"
    t.string "endpoint", null: false
    t.string "p256dh", null: false
    t.string "auth", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["guardian_id", "endpoint"], name: "index_push_subscriptions_on_guardian_id_and_endpoint", unique: true, where: "(guardian_id IS NOT NULL)"
    t.index ["guardian_id"], name: "index_push_subscriptions_on_guardian_id"
    t.index ["user_id", "endpoint"], name: "index_push_subscriptions_on_user_id_and_endpoint", unique: true, where: "(user_id IS NOT NULL)"
    t.index ["user_id"], name: "index_push_subscriptions_on_user_id"
    t.index ["workspace_id"], name: "index_push_subscriptions_on_workspace_id"
  end

  create_table "schedule_runs", force: :cascade do |t|
    t.bigint "workspace_id", null: false
    t.bigint "pool_id", null: false
    t.bigint "created_by_id"
    t.bigint "applied_by_id"
    t.date "month", null: false
    t.string "status", default: "draft", null: false
    t.jsonb "proposals", default: [], null: false
    t.jsonb "metrics", default: {}, null: false
    t.datetime "applied_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["applied_by_id"], name: "index_schedule_runs_on_applied_by_id"
    t.index ["created_by_id"], name: "index_schedule_runs_on_created_by_id"
    t.index ["pool_id"], name: "index_schedule_runs_on_pool_id"
    t.index ["workspace_id", "pool_id", "month"], name: "index_schedule_runs_on_workspace_id_and_pool_id_and_month"
    t.index ["workspace_id"], name: "index_schedule_runs_on_workspace_id"
  end

  create_table "session_feedbacks", force: :cascade do |t|
    t.bigint "workspace_id", null: false
    t.bigint "pool_id", null: false
    t.bigint "lesson_id", null: false
    t.bigint "student_id", null: false
    t.bigint "teacher_id", null: false
    t.string "tag"
    t.text "body"
    t.datetime "sent_at"
    t.datetime "read_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["lesson_id", "student_id"], name: "index_session_feedbacks_on_lesson_id_and_student_id", unique: true
    t.index ["lesson_id"], name: "index_session_feedbacks_on_lesson_id"
    t.index ["pool_id"], name: "index_session_feedbacks_on_pool_id"
    t.index ["student_id"], name: "index_session_feedbacks_on_student_id"
    t.index ["teacher_id"], name: "index_session_feedbacks_on_teacher_id"
    t.index ["workspace_id", "student_id", "created_at"], name: "index_feedbacks_on_student_time"
    t.index ["workspace_id"], name: "index_session_feedbacks_on_workspace_id"
  end

  create_table "students", force: :cascade do |t|
    t.bigint "workspace_id", null: false
    t.bigint "household_id", null: false
    t.bigint "pool_id", null: false
    t.bigint "guardian_id"
    t.string "name", null: false
    t.date "birthdate"
    t.string "gender"
    t.text "health_notes"
    t.string "source"
    t.string "kind", default: "center", null: false
    t.string "status", default: "active", null: false
    t.datetime "exam_eligible_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["guardian_id"], name: "index_students_on_guardian_id"
    t.index ["household_id"], name: "index_students_on_household_id"
    t.index ["pool_id"], name: "index_students_on_pool_id"
    t.index ["workspace_id", "name"], name: "index_students_on_workspace_id_and_name"
    t.index ["workspace_id", "pool_id"], name: "index_students_on_workspace_id_and_pool_id"
    t.index ["workspace_id"], name: "index_students_on_workspace_id"
  end

  create_table "swim_classes", force: :cascade do |t|
    t.bigint "workspace_id", null: false
    t.bigint "pool_id", null: false
    t.bigint "teacher_id", null: false
    t.bigint "course_id"
    t.string "code"
    t.integer "class_type", default: 1, null: false
    t.integer "start_hour", null: false
    t.jsonb "weekdays", default: [], null: false
    t.date "start_date", null: false
    t.date "end_date"
    t.string "status", default: "running", null: false
    t.string "kind", default: "class", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["code"], name: "index_swim_classes_on_code", unique: true, where: "(code IS NOT NULL)"
    t.index ["course_id"], name: "index_swim_classes_on_course_id"
    t.index ["pool_id"], name: "index_swim_classes_on_pool_id"
    t.index ["teacher_id"], name: "index_swim_classes_on_teacher_id"
    t.index ["workspace_id", "pool_id", "status"], name: "index_swim_classes_on_workspace_id_and_pool_id_and_status"
    t.index ["workspace_id"], name: "index_swim_classes_on_workspace_id"
  end

  create_table "teacher_availabilities", force: :cascade do |t|
    t.bigint "workspace_id", null: false
    t.bigint "teacher_id", null: false
    t.bigint "pool_id", null: false
    t.date "month", null: false
    t.integer "weekday", null: false
    t.integer "hour", null: false
    t.datetime "submitted_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["pool_id"], name: "index_teacher_availabilities_on_pool_id"
    t.index ["teacher_id", "month", "weekday", "hour", "pool_id"], name: "index_availability_unique_slot", unique: true
    t.index ["teacher_id"], name: "index_teacher_availabilities_on_teacher_id"
    t.index ["workspace_id", "pool_id", "month"], name: "idx_on_workspace_id_pool_id_month_e47adbacab"
    t.index ["workspace_id"], name: "index_teacher_availabilities_on_workspace_id"
  end

  create_table "teacher_levels", force: :cascade do |t|
    t.bigint "workspace_id", null: false
    t.string "name", null: false
    t.integer "position", default: 0, null: false
    t.integer "max_students_per_slot", default: 2, null: false
    t.integer "pay_rate_per_credit", default: 0, null: false
    t.text "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["workspace_id", "name"], name: "index_teacher_levels_on_workspace_id_and_name", unique: true
    t.index ["workspace_id"], name: "index_teacher_levels_on_workspace_id"
  end

  create_table "teacher_pools", force: :cascade do |t|
    t.bigint "workspace_id", null: false
    t.bigint "teacher_id", null: false
    t.bigint "pool_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["pool_id"], name: "index_teacher_pools_on_pool_id"
    t.index ["teacher_id", "pool_id"], name: "index_teacher_pools_on_teacher_id_and_pool_id", unique: true
    t.index ["teacher_id"], name: "index_teacher_pools_on_teacher_id"
    t.index ["workspace_id"], name: "index_teacher_pools_on_workspace_id"
  end

  create_table "teachers", force: :cascade do |t|
    t.bigint "workspace_id", null: false
    t.bigint "user_id", null: false
    t.bigint "teacher_level_id"
    t.string "kind", default: "staff", null: false
    t.string "status", default: "active", null: false
    t.string "specialty"
    t.integer "years_experience"
    t.text "bio"
    t.string "org_name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["teacher_level_id"], name: "index_teachers_on_teacher_level_id"
    t.index ["user_id"], name: "index_teachers_on_user_id"
    t.index ["workspace_id", "kind"], name: "index_teachers_on_workspace_id_and_kind"
    t.index ["workspace_id", "user_id"], name: "index_teachers_on_workspace_id_and_user_id", unique: true
    t.index ["workspace_id"], name: "index_teachers_on_workspace_id"
  end

  create_table "timesheet_entries", force: :cascade do |t|
    t.bigint "workspace_id", null: false
    t.bigint "pool_id", null: false
    t.bigint "teacher_id", null: false
    t.bigint "lesson_id", null: false
    t.bigint "payroll_period_id"
    t.integer "headcount", default: 0, null: false
    t.string "basis", default: "registered", null: false
    t.decimal "credits", precision: 5, scale: 2, default: "0.0", null: false
    t.integer "rate", default: 0, null: false
    t.integer "amount", default: 0, null: false
    t.string "status", default: "pending", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["lesson_id", "teacher_id"], name: "index_timesheet_entries_on_lesson_id_and_teacher_id", unique: true
    t.index ["lesson_id"], name: "index_timesheet_entries_on_lesson_id"
    t.index ["payroll_period_id"], name: "index_timesheet_entries_on_payroll_period_id"
    t.index ["pool_id"], name: "index_timesheet_entries_on_pool_id"
    t.index ["teacher_id"], name: "index_timesheet_entries_on_teacher_id"
    t.index ["workspace_id", "teacher_id", "created_at"], name: "index_timesheets_on_teacher_time"
    t.index ["workspace_id"], name: "index_timesheet_entries_on_workspace_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "name", default: "", null: false
    t.string "title"
    t.string "phone"
    t.string "locale", default: "vi", null: false
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.integer "sign_in_count", default: 0, null: false
    t.datetime "current_sign_in_at"
    t.datetime "last_sign_in_at"
    t.string "current_sign_in_ip"
    t.string "last_sign_in_ip"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  create_table "workspaces", force: :cascade do |t|
    t.string "name", null: false
    t.string "slug", null: false
    t.string "subdomain", null: false
    t.string "custom_domain"
    t.datetime "domain_verified_at"
    t.string "status", default: "trial", null: false
    t.string "plan", default: "starter", null: false
    t.string "locale_default", default: "vi", null: false
    t.datetime "paid_until"
    t.boolean "auto_renew", default: false, null: false
    t.jsonb "theme", default: {}, null: false
    t.jsonb "branding", default: {}, null: false
    t.jsonb "settings", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["custom_domain"], name: "index_workspaces_on_custom_domain", unique: true, where: "(custom_domain IS NOT NULL)"
    t.index ["slug"], name: "index_workspaces_on_slug", unique: true
    t.index ["status"], name: "index_workspaces_on_status"
    t.index ["subdomain"], name: "index_workspaces_on_subdomain", unique: true
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "attendances", "enrollments"
  add_foreign_key "attendances", "lessons"
  add_foreign_key "attendances", "pools"
  add_foreign_key "attendances", "students"
  add_foreign_key "attendances", "users", column: "actor_id"
  add_foreign_key "attendances", "workspaces"
  add_foreign_key "audit_logs", "pools"
  add_foreign_key "audit_logs", "users"
  add_foreign_key "audit_logs", "workspaces"
  add_foreign_key "biometric_consents", "guardians"
  add_foreign_key "biometric_consents", "students"
  add_foreign_key "biometric_consents", "workspaces"
  add_foreign_key "broadcasts", "pools"
  add_foreign_key "broadcasts", "users", column: "created_by_id"
  add_foreign_key "broadcasts", "workspaces"
  add_foreign_key "contracts", "enrollments"
  add_foreign_key "contracts", "households"
  add_foreign_key "contracts", "pools"
  add_foreign_key "contracts", "users", column: "signed_by_id"
  add_foreign_key "contracts", "workspaces"
  add_foreign_key "conversations", "households"
  add_foreign_key "conversations", "pools"
  add_foreign_key "conversations", "workspaces"
  add_foreign_key "course_sessions", "courses"
  add_foreign_key "course_sessions", "workspaces"
  add_foreign_key "courses", "workspaces"
  add_foreign_key "day_pass_tickets", "orders"
  add_foreign_key "day_pass_tickets", "pools"
  add_foreign_key "day_pass_tickets", "users", column: "issued_by_id"
  add_foreign_key "day_pass_tickets", "workspaces"
  add_foreign_key "enrollments", "packages"
  add_foreign_key "enrollments", "pools"
  add_foreign_key "enrollments", "students"
  add_foreign_key "enrollments", "swim_classes"
  add_foreign_key "enrollments", "workspaces"
  add_foreign_key "face_profiles", "students"
  add_foreign_key "face_profiles", "workspaces"
  add_foreign_key "guardians", "households"
  add_foreign_key "guardians", "workspaces"
  add_foreign_key "households", "workspaces"
  add_foreign_key "invoices", "workspaces"
  add_foreign_key "leave_requests", "teachers"
  add_foreign_key "leave_requests", "users", column: "reviewed_by_id"
  add_foreign_key "leave_requests", "workspaces"
  add_foreign_key "lessons", "pools"
  add_foreign_key "lessons", "swim_classes"
  add_foreign_key "lessons", "teachers"
  add_foreign_key "lessons", "workspaces"
  add_foreign_key "makeup_requests", "enrollments"
  add_foreign_key "makeup_requests", "guardians", column: "decided_by_id"
  add_foreign_key "makeup_requests", "leave_requests"
  add_foreign_key "makeup_requests", "lessons", column: "from_lesson_id"
  add_foreign_key "makeup_requests", "lessons", column: "to_lesson_id"
  add_foreign_key "makeup_requests", "pools"
  add_foreign_key "makeup_requests", "students"
  add_foreign_key "makeup_requests", "workspaces"
  add_foreign_key "memberships", "users"
  add_foreign_key "memberships", "workspaces"
  add_foreign_key "messages", "conversations"
  add_foreign_key "messages", "guardians"
  add_foreign_key "messages", "users"
  add_foreign_key "messages", "workspaces"
  add_foreign_key "notifications", "broadcasts"
  add_foreign_key "notifications", "workspaces"
  add_foreign_key "orders", "enrollments"
  add_foreign_key "orders", "households"
  add_foreign_key "orders", "packages"
  add_foreign_key "orders", "pools"
  add_foreign_key "orders", "students"
  add_foreign_key "orders", "users", column: "sale_id"
  add_foreign_key "orders", "workspaces"
  add_foreign_key "packages", "courses"
  add_foreign_key "packages", "workspaces"
  add_foreign_key "payments", "orders"
  add_foreign_key "payments", "users", column: "recorded_by_id"
  add_foreign_key "payments", "workspaces"
  add_foreign_key "payroll_periods", "pools"
  add_foreign_key "payroll_periods", "users", column: "locked_by_id"
  add_foreign_key "payroll_periods", "workspaces"
  add_foreign_key "pool_assignments", "pools"
  add_foreign_key "pool_assignments", "users"
  add_foreign_key "pool_assignments", "workspaces"
  add_foreign_key "pool_holidays", "pools"
  add_foreign_key "pool_holidays", "workspaces"
  add_foreign_key "pool_operating_hours", "pools"
  add_foreign_key "pool_operating_hours", "workspaces"
  add_foreign_key "pools", "workspaces"
  add_foreign_key "price_list_items", "packages"
  add_foreign_key "price_list_items", "pools"
  add_foreign_key "price_list_items", "workspaces"
  add_foreign_key "promotions", "pools"
  add_foreign_key "promotions", "workspaces"
  add_foreign_key "push_subscriptions", "guardians"
  add_foreign_key "push_subscriptions", "users"
  add_foreign_key "push_subscriptions", "workspaces"
  add_foreign_key "schedule_runs", "pools"
  add_foreign_key "schedule_runs", "users", column: "applied_by_id"
  add_foreign_key "schedule_runs", "users", column: "created_by_id"
  add_foreign_key "schedule_runs", "workspaces"
  add_foreign_key "session_feedbacks", "lessons"
  add_foreign_key "session_feedbacks", "pools"
  add_foreign_key "session_feedbacks", "students"
  add_foreign_key "session_feedbacks", "teachers"
  add_foreign_key "session_feedbacks", "workspaces"
  add_foreign_key "students", "guardians"
  add_foreign_key "students", "households"
  add_foreign_key "students", "pools"
  add_foreign_key "students", "workspaces"
  add_foreign_key "swim_classes", "courses"
  add_foreign_key "swim_classes", "pools"
  add_foreign_key "swim_classes", "teachers"
  add_foreign_key "swim_classes", "workspaces"
  add_foreign_key "teacher_availabilities", "pools"
  add_foreign_key "teacher_availabilities", "teachers"
  add_foreign_key "teacher_availabilities", "workspaces"
  add_foreign_key "teacher_levels", "workspaces"
  add_foreign_key "teacher_pools", "pools"
  add_foreign_key "teacher_pools", "teachers"
  add_foreign_key "teacher_pools", "workspaces"
  add_foreign_key "teachers", "teacher_levels"
  add_foreign_key "teachers", "users"
  add_foreign_key "teachers", "workspaces"
  add_foreign_key "timesheet_entries", "lessons"
  add_foreign_key "timesheet_entries", "payroll_periods"
  add_foreign_key "timesheet_entries", "pools"
  add_foreign_key "timesheet_entries", "teachers"
  add_foreign_key "timesheet_entries", "workspaces"
end
