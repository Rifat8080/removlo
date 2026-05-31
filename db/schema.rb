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

ActiveRecord::Schema[8.0].define(version: 2026_05_31_090000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"
  enable_extension "pgcrypto"

  create_table "notifications", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "user_id", null: false
    t.uuid "actor_id"
    t.string "event_type", null: false
    t.string "title", null: false
    t.text "body"
    t.string "url"
    t.string "notifiable_type"
    t.uuid "notifiable_id"
    t.jsonb "metadata", default: {}, null: false
    t.datetime "read_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["actor_id"], name: "index_notifications_on_actor_id"
    t.index ["notifiable_type", "notifiable_id"], name: "index_notifications_on_notifiable_type_and_notifiable_id"
    t.index ["user_id", "created_at"], name: "index_notifications_on_user_id_and_created_at"
    t.index ["user_id", "read_at"], name: "index_notifications_on_user_id_and_read_at"
    t.index ["user_id"], name: "index_notifications_on_user_id"
  end

  create_table "quotation_documents", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "quotation_id", null: false
    t.string "title", null: false
    t.string "document_type", default: "other", null: false
    t.string "url"
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["quotation_id"], name: "index_quotation_documents_on_quotation_id"
  end

  create_table "quotation_items", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "quotation_id", null: false
    t.string "name", null: false
    t.integer "quantity", default: 1, null: false
    t.boolean "fragile", default: false, null: false
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["quotation_id"], name: "index_quotation_items_on_quotation_id"
  end

  create_table "quotation_notes", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "quotation_id", null: false
    t.uuid "user_id"
    t.text "content", null: false
    t.boolean "internal", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["quotation_id"], name: "index_quotation_notes_on_quotation_id"
    t.index ["user_id"], name: "index_quotation_notes_on_user_id"
  end

  create_table "quotation_payments", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "quotation_id", null: false
    t.integer "amount_cents", default: 0, null: false
    t.string "payment_method", default: "manual", null: false
    t.string "status", default: "recorded", null: false
    t.date "paid_on"
    t.string "reference"
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["quotation_id"], name: "index_quotation_payments_on_quotation_id"
  end

  create_table "quotation_status_events", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "quotation_id", null: false
    t.uuid "user_id"
    t.string "from_status"
    t.string "to_status", null: false
    t.text "note"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["quotation_id"], name: "index_quotation_status_events_on_quotation_id"
    t.index ["user_id"], name: "index_quotation_status_events_on_user_id"
  end

  create_table "quotations", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "reference", null: false
    t.uuid "customer_id", null: false
    t.uuid "created_by_id"
    t.uuid "assigned_staff_id"
    t.string "status", default: "draft", null: false
    t.string "move_size", default: "studio", null: false
    t.string "service_level", default: "standard", null: false
    t.date "preferred_move_date"
    t.datetime "scheduled_at"
    t.string "pickup_postcode"
    t.string "delivery_postcode"
    t.text "pickup_address", null: false
    t.text "delivery_address", null: false
    t.text "access_notes"
    t.text "customer_notes"
    t.integer "quoted_price_cents", default: 0, null: false
    t.integer "deposit_cents", default: 0, null: false
    t.string "payment_status", default: "unpaid", null: false
    t.datetime "quoted_at"
    t.datetime "accepted_at"
    t.datetime "completed_at"
    t.datetime "cancelled_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.uuid "assigned_driver_id"
    t.index ["assigned_driver_id"], name: "index_quotations_on_assigned_driver_id"
    t.index ["assigned_staff_id"], name: "index_quotations_on_assigned_staff_id"
    t.index ["created_by_id"], name: "index_quotations_on_created_by_id"
    t.index ["customer_id"], name: "index_quotations_on_customer_id"
    t.index ["payment_status"], name: "index_quotations_on_payment_status"
    t.index ["preferred_move_date"], name: "index_quotations_on_preferred_move_date"
    t.index ["reference"], name: "index_quotations_on_reference", unique: true
    t.index ["status"], name: "index_quotations_on_status"
  end

  create_table "users", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "role", default: "customer", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
    t.index ["role"], name: "index_users_on_role"
  end

  create_table "web_push_subscriptions", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "user_id", null: false
    t.string "endpoint", null: false
    t.text "p256dh_key", null: false
    t.text "auth_key", null: false
    t.string "user_agent"
    t.datetime "last_success_at"
    t.datetime "last_failure_at"
    t.text "last_error"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["endpoint"], name: "index_web_push_subscriptions_on_endpoint", unique: true
    t.index ["user_id"], name: "index_web_push_subscriptions_on_user_id"
  end

  add_foreign_key "notifications", "users"
  add_foreign_key "notifications", "users", column: "actor_id"
  add_foreign_key "quotation_documents", "quotations"
  add_foreign_key "quotation_items", "quotations"
  add_foreign_key "quotation_notes", "quotations"
  add_foreign_key "quotation_notes", "users"
  add_foreign_key "quotation_payments", "quotations"
  add_foreign_key "quotation_status_events", "quotations"
  add_foreign_key "quotation_status_events", "users"
  add_foreign_key "quotations", "users", column: "assigned_driver_id"
  add_foreign_key "quotations", "users", column: "assigned_staff_id"
  add_foreign_key "quotations", "users", column: "created_by_id"
  add_foreign_key "quotations", "users", column: "customer_id"
  add_foreign_key "web_push_subscriptions", "users"
end
