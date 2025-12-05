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

ActiveRecord::Schema[8.1].define(version: 2025_12_04_165356) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"
  enable_extension "pgcrypto"

  create_table "activity_flows", force: :cascade do |t|
    t.bigint "cbv_applicant_id", null: false
    t.datetime "completed_at"
    t.datetime "created_at", null: false
    t.string "device_id"
    t.bigint "identity_id"
    t.datetime "updated_at", null: false
    t.index ["cbv_applicant_id"], name: "index_activity_flows_on_cbv_applicant_id"
    t.index ["identity_id"], name: "index_activity_flows_on_identity_id"
  end

  create_table "api_access_tokens", force: :cascade do |t|
    t.string "access_token"
    t.datetime "created_at", null: false
    t.datetime "deleted_at"
    t.datetime "updated_at", null: false
    t.integer "user_id"
  end

  create_table "cbv_applicants", force: :cascade do |t|
    t.string "agency_id_number"
    t.string "beacon_id"
    t.string "case_number"
    t.string "client_agency_id"
    t.string "client_id_number"
    t.datetime "created_at", null: false
    t.date "date_of_birth"
    t.string "doc_id"
    t.string "first_name"
    t.jsonb "income_changes"
    t.string "last_name"
    t.string "middle_name"
    t.datetime "redacted_at"
    t.date "snap_application_date"
    t.datetime "updated_at", null: false
  end

  create_table "cbv_flow_invitations", force: :cascade do |t|
    t.string "auth_token"
    t.bigint "cbv_applicant_id"
    t.string "client_agency_id"
    t.datetime "created_at", null: false
    t.string "email_address"
    t.datetime "expires_at", precision: nil
    t.string "language"
    t.datetime "redacted_at"
    t.datetime "updated_at", null: false
    t.bigint "user_id"
    t.index ["auth_token"], name: "index_cbv_flow_invitations_on_auth_token", unique: true, where: "(redacted_at IS NULL)"
    t.index ["cbv_applicant_id"], name: "index_cbv_flow_invitations_on_cbv_applicant_id"
    t.index ["user_id"], name: "index_cbv_flow_invitations_on_user_id"
  end

  create_table "cbv_flows", force: :cascade do |t|
    t.jsonb "additional_information", default: {}
    t.string "argyle_user_id"
    t.bigint "cbv_applicant_id"
    t.bigint "cbv_flow_invitation_id"
    t.string "confirmation_code"
    t.datetime "consented_to_authorized_use_at"
    t.datetime "created_at", null: false
    t.string "device_id"
    t.uuid "end_user_id", default: -> { "gen_random_uuid()" }, null: false
    t.boolean "has_other_jobs"
    t.date "payroll_data_available_from"
    t.string "pinwheel_token_id"
    t.datetime "redacted_at"
    t.datetime "transmitted_at"
    t.datetime "updated_at", null: false
    t.index ["cbv_applicant_id"], name: "index_cbv_flows_on_cbv_applicant_id"
    t.index ["cbv_flow_invitation_id"], name: "index_cbv_flows_on_cbv_flow_invitation_id"
  end

  create_table "education_activities", force: :cascade do |t|
    t.bigint "activity_flow_id", null: false
    t.text "additional_comments"
    t.boolean "confirmed", default: false
    t.datetime "created_at", null: false
    t.integer "credit_hours"
    t.string "school_address"
    t.string "school_name"
    t.string "status"
    t.datetime "updated_at", null: false
    t.index ["activity_flow_id"], name: "index_education_activities_on_activity_flow_id"
  end

  create_table "education_activities_enrollments", id: false, force: :cascade do |t|
    t.bigint "education_activity_id", null: false
    t.bigint "enrollment_id", null: false
  end

  create_table "enrollments", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "education_activity_id"
    t.bigint "school_id", null: false
    t.date "semester_start"
    t.string "status"
    t.datetime "updated_at", null: false
    t.index ["education_activity_id"], name: "index_enrollments_on_education_activity_id"
    t.index ["school_id"], name: "index_enrollments_on_school_id"
  end

  create_table "identities", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.date "date_of_birth", null: false
    t.string "first_name", null: false
    t.string "last_name", null: false
    t.datetime "updated_at", null: false
    t.index ["first_name", "last_name", "date_of_birth"], name: "index_identities_on_first_name_and_last_name_and_date_of_birth", unique: true
  end

  create_table "job_training_activities", force: :cascade do |t|
    t.bigint "activity_flow_id", null: false
    t.datetime "created_at", null: false
    t.integer "hours"
    t.string "organization_address"
    t.string "program_name"
    t.datetime "updated_at", null: false
    t.index ["activity_flow_id"], name: "index_job_training_activities_on_activity_flow_id"
  end

  create_table "payroll_accounts", force: :cascade do |t|
    t.string "aggregator_account_id"
    t.bigint "cbv_flow_id", null: false
    t.datetime "created_at", null: false
    t.datetime "income_synced_at", precision: nil
    t.datetime "redacted_at"
    t.string "supported_jobs", default: [], array: true
    t.string "synchronization_status", default: "unknown"
    t.string "type", default: "pinwheel", null: false
    t.datetime "updated_at", null: false
    t.index ["cbv_flow_id"], name: "index_payroll_accounts_on_cbv_flow_id"
  end

  create_table "schools", force: :cascade do |t|
    t.string "address"
    t.datetime "created_at", null: false
    t.bigint "identity_id", null: false
    t.string "name"
    t.datetime "updated_at", null: false
    t.index ["identity_id"], name: "index_schools_on_identity_id"
  end

  create_table "solid_queue_blocked_executions", force: :cascade do |t|
    t.string "concurrency_key", null: false
    t.datetime "created_at", null: false
    t.datetime "expires_at", null: false
    t.bigint "job_id", null: false
    t.integer "priority", default: 0, null: false
    t.string "queue_name", null: false
    t.index ["concurrency_key", "priority", "job_id"], name: "index_solid_queue_blocked_executions_for_release"
    t.index ["expires_at", "concurrency_key"], name: "index_solid_queue_blocked_executions_for_maintenance"
    t.index ["job_id"], name: "index_solid_queue_blocked_executions_on_job_id", unique: true
  end

  create_table "solid_queue_claimed_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.bigint "process_id"
    t.index ["job_id"], name: "index_solid_queue_claimed_executions_on_job_id", unique: true
    t.index ["process_id", "job_id"], name: "index_solid_queue_claimed_executions_on_process_id_and_job_id"
  end

  create_table "solid_queue_failed_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "error"
    t.bigint "job_id", null: false
    t.index ["job_id"], name: "index_solid_queue_failed_executions_on_job_id", unique: true
  end

  create_table "solid_queue_jobs", force: :cascade do |t|
    t.string "active_job_id"
    t.text "arguments"
    t.string "class_name", null: false
    t.string "concurrency_key"
    t.datetime "created_at", null: false
    t.datetime "finished_at"
    t.integer "priority", default: 0, null: false
    t.string "queue_name", null: false
    t.datetime "scheduled_at"
    t.datetime "updated_at", null: false
    t.index ["active_job_id"], name: "index_solid_queue_jobs_on_active_job_id"
    t.index ["class_name"], name: "index_solid_queue_jobs_on_class_name"
    t.index ["finished_at"], name: "index_solid_queue_jobs_on_finished_at"
    t.index ["queue_name", "finished_at"], name: "index_solid_queue_jobs_for_filtering"
    t.index ["scheduled_at", "finished_at"], name: "index_solid_queue_jobs_for_alerting"
  end

  create_table "solid_queue_pauses", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "queue_name", null: false
    t.index ["queue_name"], name: "index_solid_queue_pauses_on_queue_name", unique: true
  end

  create_table "solid_queue_processes", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "hostname"
    t.string "kind", null: false
    t.datetime "last_heartbeat_at", null: false
    t.text "metadata"
    t.string "name", null: false
    t.integer "pid", null: false
    t.bigint "supervisor_id"
    t.index ["last_heartbeat_at"], name: "index_solid_queue_processes_on_last_heartbeat_at"
    t.index ["name", "supervisor_id"], name: "index_solid_queue_processes_on_name_and_supervisor_id", unique: true
    t.index ["supervisor_id"], name: "index_solid_queue_processes_on_supervisor_id"
  end

  create_table "solid_queue_ready_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.integer "priority", default: 0, null: false
    t.string "queue_name", null: false
    t.index ["job_id"], name: "index_solid_queue_ready_executions_on_job_id", unique: true
    t.index ["priority", "job_id"], name: "index_solid_queue_poll_all"
    t.index ["queue_name", "priority", "job_id"], name: "index_solid_queue_poll_by_queue"
  end

  create_table "solid_queue_recurring_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.datetime "run_at", null: false
    t.string "task_key", null: false
    t.index ["job_id"], name: "index_solid_queue_recurring_executions_on_job_id", unique: true
    t.index ["task_key", "run_at"], name: "index_solid_queue_recurring_executions_on_task_key_and_run_at", unique: true
  end

  create_table "solid_queue_recurring_tasks", force: :cascade do |t|
    t.text "arguments"
    t.string "class_name"
    t.string "command", limit: 2048
    t.datetime "created_at", null: false
    t.text "description"
    t.string "key", null: false
    t.integer "priority", default: 0
    t.string "queue_name"
    t.string "schedule", null: false
    t.boolean "static", default: true, null: false
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_solid_queue_recurring_tasks_on_key", unique: true
    t.index ["static"], name: "index_solid_queue_recurring_tasks_on_static"
  end

  create_table "solid_queue_scheduled_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.integer "priority", default: 0, null: false
    t.string "queue_name", null: false
    t.datetime "scheduled_at", null: false
    t.index ["job_id"], name: "index_solid_queue_scheduled_executions_on_job_id", unique: true
    t.index ["scheduled_at", "priority", "job_id"], name: "index_solid_queue_dispatch_all"
  end

  create_table "solid_queue_semaphores", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "expires_at", null: false
    t.string "key", null: false
    t.datetime "updated_at", null: false
    t.integer "value", default: 1, null: false
    t.index ["expires_at"], name: "index_solid_queue_semaphores_on_expires_at"
    t.index ["key", "value"], name: "index_solid_queue_semaphores_on_key_and_value"
    t.index ["key"], name: "index_solid_queue_semaphores_on_key", unique: true
  end

  create_table "users", force: :cascade do |t|
    t.string "client_agency_id", null: false
    t.datetime "created_at", null: false
    t.datetime "current_sign_in_at"
    t.string "current_sign_in_ip"
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.jsonb "invalidated_session_ids"
    t.boolean "is_service_account", default: false
    t.datetime "last_sign_in_at"
    t.string "last_sign_in_ip"
    t.datetime "remember_created_at"
    t.datetime "reset_password_sent_at"
    t.string "reset_password_token"
    t.integer "sign_in_count", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["email", "client_agency_id"], name: "index_users_on_email_and_client_agency_id", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  create_table "volunteering_activities", force: :cascade do |t|
    t.bigint "activity_flow_id", null: false
    t.datetime "created_at", null: false
    t.date "date"
    t.integer "hours"
    t.string "organization_name"
    t.datetime "updated_at", null: false
    t.index ["activity_flow_id"], name: "index_volunteering_activities_on_activity_flow_id"
  end

  create_table "webhook_events", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "event_name"
    t.string "event_outcome"
    t.bigint "payroll_account_id", null: false
    t.datetime "updated_at", null: false
    t.index ["payroll_account_id"], name: "index_webhook_events_on_payroll_account_id"
  end

  add_foreign_key "activity_flows", "cbv_applicants"
  add_foreign_key "activity_flows", "identities"
  add_foreign_key "cbv_flow_invitations", "users"
  add_foreign_key "cbv_flows", "cbv_flow_invitations"
  add_foreign_key "education_activities", "activity_flows"
  add_foreign_key "enrollments", "education_activities"
  add_foreign_key "enrollments", "schools"
  add_foreign_key "job_training_activities", "activity_flows"
  add_foreign_key "payroll_accounts", "cbv_flows"
  add_foreign_key "schools", "identities"
  add_foreign_key "solid_queue_blocked_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_claimed_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_failed_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_ready_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_recurring_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_scheduled_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "volunteering_activities", "activity_flows"
  add_foreign_key "webhook_events", "payroll_accounts"
end
