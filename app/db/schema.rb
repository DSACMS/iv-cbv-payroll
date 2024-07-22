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

ActiveRecord::Schema[7.1].define(version: 2024_07_22_152722) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "applicants", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "cbv_flow_invitations", force: :cascade do |t|
    t.string "email_address"
    t.string "case_number"
    t.string "auth_token"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "cbv_flows", force: :cascade do |t|
    t.string "case_number"
    t.string "argyle_user_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.date "payroll_data_available_from"
    t.bigint "cbv_flow_invitation_id"
    t.string "pinwheel_token_id"
    t.uuid "pinwheel_end_user_id", default: -> { "gen_random_uuid()" }, null: false
    t.jsonb "additional_information", default: {}
    t.string "confirmation_number"
    t.index ["cbv_flow_invitation_id"], name: "index_cbv_flows_on_cbv_flow_invitation_id"
  end

  create_table "connected_argyle_accounts", force: :cascade do |t|
    t.uuid "user_id", null: false
    t.uuid "account_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id", "account_id"], name: "index_connected_argyle_accounts_on_user_id_and_account_id", unique: true
  end

  add_foreign_key "cbv_flows", "cbv_flow_invitations"
end
