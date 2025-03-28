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

ActiveRecord::Schema[7.1].define(version: 2025_03_18_171130) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pgcrypto"
  enable_extension "plpgsql"

  create_table "api_access_tokens", force: :cascade do |t|
    t.string "access_token"
    t.integer "user_id"
    t.datetime "deleted_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "cbv_applicants", force: :cascade do |t|
    t.string "case_number"
    t.string "first_name"
    t.string "middle_name"
    t.string "last_name"
    t.string "agency_id_number"
    t.string "client_id_number"
    t.date "snap_application_date"
    t.string "beacon_id"
    t.datetime "redacted_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "client_agency_id"
  end

  create_table "cbv_flow_invitations", force: :cascade do |t|
    t.string "email_address"
    t.string "auth_token"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "client_agency_id"
    t.datetime "redacted_at"
    t.bigint "user_id"
    t.string "language"
    t.bigint "cbv_applicant_id"
    t.index ["cbv_applicant_id"], name: "index_cbv_flow_invitations_on_cbv_applicant_id"
    t.index ["user_id"], name: "index_cbv_flow_invitations_on_user_id"
  end

  create_table "cbv_flows", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.date "payroll_data_available_from"
    t.bigint "cbv_flow_invitation_id"
    t.string "pinwheel_token_id"
    t.uuid "end_user_id", default: -> { "gen_random_uuid()" }, null: false
    t.jsonb "additional_information", default: {}
    t.string "client_agency_id"
    t.string "confirmation_code"
    t.datetime "transmitted_at"
    t.datetime "consented_to_authorized_use_at"
    t.datetime "redacted_at"
    t.bigint "cbv_applicant_id"
    t.index ["cbv_applicant_id"], name: "index_cbv_flows_on_cbv_applicant_id"
    t.index ["cbv_flow_invitation_id"], name: "index_cbv_flows_on_cbv_flow_invitation_id"
  end

  create_table "payroll_accounts", force: :cascade do |t|
    t.bigint "cbv_flow_id", null: false
    t.string "pinwheel_account_id"
    t.datetime "paystubs_synced_at", precision: nil
    t.datetime "employment_synced_at", precision: nil
    t.datetime "income_synced_at", precision: nil
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "supported_jobs", default: [], array: true
    t.datetime "employment_errored_at", precision: nil
    t.datetime "income_errored_at", precision: nil
    t.datetime "paystubs_errored_at", precision: nil
    t.datetime "identity_errored_at", precision: nil
    t.datetime "identity_synced_at", precision: nil
    t.string "type", default: "pinwheel", null: false
    t.index ["cbv_flow_id"], name: "index_payroll_accounts_on_cbv_flow_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "client_agency_id", null: false
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
    t.jsonb "invalidated_session_ids"
    t.boolean "is_service_account", default: false
    t.index ["email", "client_agency_id"], name: "index_users_on_email_and_client_agency_id", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  create_table "webhook_events", force: :cascade do |t|
    t.string "event_name"
    t.string "event_outcome"
    t.bigint "payroll_account_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["payroll_account_id"], name: "index_webhook_events_on_payroll_account_id"
  end

  add_foreign_key "cbv_flow_invitations", "users"
  add_foreign_key "cbv_flows", "cbv_flow_invitations"
  add_foreign_key "payroll_accounts", "cbv_flows"
  add_foreign_key "webhook_events", "payroll_accounts"
end
