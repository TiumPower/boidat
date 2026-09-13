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

ActiveRecord::Schema[7.2].define(version: 2026_09_13_000016) do
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

  create_table "app_settings", force: :cascade do |t|
    t.string "key", null: false
    t.text "value"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_app_settings_on_key", unique: true
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
    t.index ["household_id"], name: "index_guardians_on_household_id"
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

  create_table "otp_challenges", force: :cascade do |t|
    t.bigint "workspace_id"
    t.string "identity", null: false
    t.string "scope", default: "staff", null: false
    t.string "code", null: false
    t.string "purpose", default: "login", null: false
    t.integer "attempts", default: 0, null: false
    t.datetime "expires_at", null: false
    t.datetime "consumed_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["scope", "identity"], name: "index_otp_challenges_on_scope_and_identity"
    t.index ["workspace_id", "identity"], name: "index_otp_challenges_on_workspace_id_and_identity"
    t.index ["workspace_id"], name: "index_otp_challenges_on_workspace_id"
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
  add_foreign_key "audit_logs", "pools"
  add_foreign_key "audit_logs", "users"
  add_foreign_key "audit_logs", "workspaces"
  add_foreign_key "biometric_consents", "guardians"
  add_foreign_key "biometric_consents", "students"
  add_foreign_key "biometric_consents", "workspaces"
  add_foreign_key "broadcasts", "pools"
  add_foreign_key "broadcasts", "users", column: "created_by_id"
  add_foreign_key "broadcasts", "workspaces"
  add_foreign_key "face_profiles", "students"
  add_foreign_key "face_profiles", "workspaces"
  add_foreign_key "guardians", "households"
  add_foreign_key "guardians", "workspaces"
  add_foreign_key "households", "workspaces"
  add_foreign_key "invoices", "workspaces"
  add_foreign_key "memberships", "users"
  add_foreign_key "memberships", "workspaces"
  add_foreign_key "notifications", "broadcasts"
  add_foreign_key "notifications", "workspaces"
  add_foreign_key "otp_challenges", "workspaces"
  add_foreign_key "pool_assignments", "pools"
  add_foreign_key "pool_assignments", "users"
  add_foreign_key "pool_assignments", "workspaces"
  add_foreign_key "pool_holidays", "pools"
  add_foreign_key "pool_holidays", "workspaces"
  add_foreign_key "pool_operating_hours", "pools"
  add_foreign_key "pool_operating_hours", "workspaces"
  add_foreign_key "pools", "workspaces"
  add_foreign_key "push_subscriptions", "guardians"
  add_foreign_key "push_subscriptions", "users"
  add_foreign_key "push_subscriptions", "workspaces"
  add_foreign_key "students", "guardians"
  add_foreign_key "students", "households"
  add_foreign_key "students", "pools"
  add_foreign_key "students", "workspaces"
  add_foreign_key "teacher_levels", "workspaces"
  add_foreign_key "teacher_pools", "pools"
  add_foreign_key "teacher_pools", "teachers"
  add_foreign_key "teacher_pools", "workspaces"
  add_foreign_key "teachers", "teacher_levels"
  add_foreign_key "teachers", "users"
  add_foreign_key "teachers", "workspaces"
end
