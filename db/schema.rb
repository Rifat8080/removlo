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

ActiveRecord::Schema[8.0].define(version: 2026_06_08_140000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"
  enable_extension "pgcrypto"

  create_table "accounting_categories", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "name", null: false
    t.string "slug", null: false
    t.string "category_type", default: "expense", null: false
    t.text "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["slug"], name: "index_accounting_categories_on_slug", unique: true
  end

  create_table "accounting_transactions", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "accounting_category_id"
    t.uuid "user_id"
    t.uuid "quotation_id"
    t.uuid "quotation_payment_id"
    t.string "transaction_type", null: false
    t.integer "amount_cents", default: 0, null: false
    t.date "transaction_date", null: false
    t.string "description"
    t.string "vendor_payee"
    t.string "payment_method"
    t.string "reference"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["accounting_category_id"], name: "index_accounting_transactions_on_accounting_category_id"
    t.index ["quotation_id"], name: "index_accounting_transactions_on_quotation_id"
    t.index ["quotation_payment_id"], name: "index_accounting_transactions_on_quotation_payment_id"
    t.index ["quotation_payment_id"], name: "index_accounting_transactions_on_quotation_payment_unique", unique: true, where: "(quotation_payment_id IS NOT NULL)"
    t.index ["transaction_type", "transaction_date"], name: "index_accounting_transactions_on_type_and_date"
    t.index ["user_id"], name: "index_accounting_transactions_on_user_id"
  end

  create_table "active_storage_attachments", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.uuid "record_id", null: false
    t.uuid "blob_id", null: false
    t.datetime "created_at", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
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

  create_table "active_storage_variant_records", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "blog_posts", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "author_id", null: false
    t.string "title", null: false
    t.string "slug", null: false
    t.text "excerpt"
    t.text "body", null: false
    t.datetime "published_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["author_id"], name: "index_blog_posts_on_author_id"
    t.index ["published_at"], name: "index_blog_posts_on_published_at"
    t.index ["slug"], name: "index_blog_posts_on_slug", unique: true
  end

  create_table "cart_items", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "cart_id", null: false
    t.uuid "product_id", null: false
    t.integer "quantity", default: 1, null: false
    t.integer "unit_price_cents", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["cart_id", "product_id"], name: "index_cart_items_on_cart_id_and_product_id", unique: true
    t.index ["cart_id"], name: "index_cart_items_on_cart_id"
    t.index ["product_id"], name: "index_cart_items_on_product_id"
  end

  create_table "carts", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "user_id"
    t.string "session_token"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["session_token"], name: "index_carts_on_session_token", unique: true, where: "(session_token IS NOT NULL)"
    t.index ["user_id"], name: "index_carts_on_user_id"
  end

  create_table "conversation_participants", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "conversation_id", null: false
    t.uuid "user_id", null: false
    t.string "participant_role", null: false
    t.datetime "last_read_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["conversation_id", "user_id"], name: "index_conversation_participants_on_conversation_id_and_user_id", unique: true
    t.index ["conversation_id"], name: "index_conversation_participants_on_conversation_id"
    t.index ["user_id"], name: "index_conversation_participants_on_user_id"
  end

  create_table "conversations", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "kind", default: "support", null: false
    t.string "status", default: "open", null: false
    t.string "subject"
    t.string "conversationable_type"
    t.uuid "conversationable_id"
    t.datetime "last_message_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["conversationable_type", "conversationable_id"], name: "idx_on_conversationable_type_conversationable_id_3a28560d11"
    t.index ["kind"], name: "index_conversations_on_kind"
    t.index ["status"], name: "index_conversations_on_status"
  end

  create_table "customer_invoices", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "invoice_number", null: false
    t.string "invoice_type", default: "standard", null: false
    t.uuid "customer_id", null: false
    t.uuid "quotation_id"
    t.uuid "quotation_payment_id"
    t.integer "amount_cents", default: 0, null: false
    t.string "status", default: "issued", null: false
    t.date "issued_on", null: false
    t.date "settled_on"
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["customer_id"], name: "index_customer_invoices_on_customer_id"
    t.index ["invoice_number"], name: "index_customer_invoices_on_invoice_number", unique: true
    t.index ["quotation_id"], name: "index_customer_invoices_on_quotation_id"
    t.index ["quotation_payment_id"], name: "index_customer_invoices_on_quotation_payment_id"
    t.index ["quotation_payment_id"], name: "index_customer_invoices_on_quotation_payment_unique", unique: true, where: "(quotation_payment_id IS NOT NULL)"
  end

  create_table "driver_availabilities", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "driver_id", null: false
    t.date "available_on", null: false
    t.string "status", default: "available", null: false
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["driver_id", "available_on"], name: "index_driver_availabilities_on_driver_id_and_available_on", unique: true
    t.index ["driver_id"], name: "index_driver_availabilities_on_driver_id"
  end

  create_table "driver_offers", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "quotation_id", null: false
    t.uuid "driver_id", null: false
    t.integer "amount_cents", null: false
    t.string "status", default: "submitted", null: false
    t.decimal "score", precision: 8, scale: 4
    t.jsonb "score_breakdown", default: {}, null: false
    t.boolean "selected_by_admin", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["driver_id"], name: "index_driver_offers_on_driver_id"
    t.index ["quotation_id", "driver_id"], name: "index_driver_offers_on_quotation_id_and_driver_id", unique: true
    t.index ["quotation_id"], name: "index_driver_offers_on_quotation_id"
  end

  create_table "driver_profiles", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "user_id", null: false
    t.string "vehicle_type", default: "luton_van", null: false
    t.string "service_areas", default: [], null: false, array: true
    t.decimal "rating", precision: 3, scale: 2, default: "5.0", null: false
    t.integer "completed_jobs_count", default: 0, null: false
    t.decimal "completion_rate", precision: 5, scale: 2, default: "100.0", null: false
    t.decimal "cancellation_rate", precision: 5, scale: 2, default: "0.0", null: false
    t.integer "late_arrivals_count", default: 0, null: false
    t.integer "revenue_generated_cents", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_driver_profiles_on_user_id", unique: true
  end

  create_table "driver_wallet_entries", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "driver_id", null: false
    t.uuid "quotation_id"
    t.uuid "approved_by_id"
    t.string "entry_type", null: false
    t.string "status", default: "pending", null: false
    t.integer "amount_cents", null: false
    t.string "reference"
    t.text "notes"
    t.datetime "approved_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["approved_by_id"], name: "index_driver_wallet_entries_on_approved_by_id"
    t.index ["driver_id"], name: "index_driver_wallet_entries_on_driver_id"
    t.index ["quotation_id"], name: "index_driver_wallet_entries_on_quotation_id"
  end

  create_table "material_order_items", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "material_order_id", null: false
    t.uuid "product_id"
    t.string "product_name", null: false
    t.string "product_sku", null: false
    t.integer "quantity", default: 1, null: false
    t.integer "unit_price_cents", default: 0, null: false
    t.integer "line_total_cents", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["material_order_id"], name: "index_material_order_items_on_material_order_id"
    t.index ["product_id"], name: "index_material_order_items_on_product_id"
  end

  create_table "material_orders", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "customer_id"
    t.string "order_number", null: false
    t.string "customer_email", null: false
    t.string "fulfillment_type", default: "delivery", null: false
    t.string "status", default: "pending", null: false
    t.string "payment_status", default: "unpaid", null: false
    t.integer "subtotal_cents", default: 0, null: false
    t.integer "delivery_fee_cents", default: 0, null: false
    t.integer "total_cents", default: 0, null: false
    t.string "stripe_checkout_session_id"
    t.string "stripe_payment_intent_id"
    t.string "delivery_name"
    t.string "delivery_phone"
    t.text "delivery_address"
    t.string "delivery_postcode"
    t.date "preferred_date"
    t.string "preferred_window"
    t.text "collection_instructions"
    t.text "customer_notes"
    t.text "admin_notes"
    t.datetime "paid_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.uuid "cart_id"
    t.index ["cart_id"], name: "index_material_orders_on_cart_id"
    t.index ["customer_id"], name: "index_material_orders_on_customer_id"
    t.index ["order_number"], name: "index_material_orders_on_order_number", unique: true
    t.index ["payment_status"], name: "index_material_orders_on_payment_status"
    t.index ["status"], name: "index_material_orders_on_status"
    t.index ["stripe_checkout_session_id"], name: "index_material_orders_on_stripe_checkout_session_id", unique: true, where: "(stripe_checkout_session_id IS NOT NULL)"
  end

  create_table "messages", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "conversation_id", null: false
    t.uuid "sender_id", null: false
    t.text "body", null: false
    t.boolean "system_message", default: false, null: false
    t.boolean "internal_only", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["conversation_id", "created_at"], name: "index_messages_on_conversation_id_and_created_at"
    t.index ["conversation_id"], name: "index_messages_on_conversation_id"
    t.index ["sender_id"], name: "index_messages_on_sender_id"
  end

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

  create_table "payroll_runs", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.date "period_start", null: false
    t.date "period_end", null: false
    t.string "status", default: "draft", null: false
    t.text "notes"
    t.uuid "created_by_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["created_by_id"], name: "index_payroll_runs_on_created_by_id"
  end

  create_table "payslips", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "payroll_run_id", null: false
    t.uuid "employee_id", null: false
    t.string "employee_role", null: false
    t.integer "base_salary_cents", default: 0, null: false
    t.integer "bonus_cents", default: 0, null: false
    t.integer "commission_cents", default: 0, null: false
    t.integer "deductions_cents", default: 0, null: false
    t.integer "net_pay_cents", default: 0, null: false
    t.date "payment_date"
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["employee_id"], name: "index_payslips_on_employee_id"
    t.index ["payroll_run_id", "employee_id"], name: "index_payslips_on_payroll_run_id_and_employee_id", unique: true
    t.index ["payroll_run_id"], name: "index_payslips_on_payroll_run_id"
  end

  create_table "product_categories", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "name", null: false
    t.string "slug", null: false
    t.text "description"
    t.integer "position", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["slug"], name: "index_product_categories_on_slug", unique: true
  end

  create_table "products", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "product_category_id"
    t.string "name", null: false
    t.string "slug", null: false
    t.string "sku", null: false
    t.text "description"
    t.integer "price_cents", default: 0, null: false
    t.integer "stock_quantity", default: 0, null: false
    t.string "status", default: "active", null: false
    t.boolean "featured", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["product_category_id"], name: "index_products_on_product_category_id"
    t.index ["sku"], name: "index_products_on_sku", unique: true
    t.index ["slug"], name: "index_products_on_slug", unique: true
    t.index ["status"], name: "index_products_on_status"
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
    t.string "stripe_checkout_session_id"
    t.string "stripe_payment_intent_id"
    t.index ["quotation_id"], name: "index_quotation_payments_on_quotation_id"
    t.index ["stripe_checkout_session_id"], name: "index_quotation_payments_on_stripe_checkout_session_id", unique: true, where: "(stripe_checkout_session_id IS NOT NULL)"
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
    t.integer "driver_cost_cents", default: 0, null: false
    t.decimal "markup_percentage", precision: 5, scale: 2, default: "30.0", null: false
    t.integer "admin_margin_cents", default: 0, null: false
    t.string "vehicle_required", default: "luton_van"
    t.integer "expected_duration_hours"
    t.string "property_type"
    t.boolean "awaiting_driver_offers", default: false, null: false
    t.boolean "customer_details_released", default: false, null: false
    t.uuid "selected_driver_offer_id"
    t.string "public_share_token", null: false
    t.index ["assigned_driver_id"], name: "index_quotations_on_assigned_driver_id"
    t.index ["assigned_staff_id"], name: "index_quotations_on_assigned_staff_id"
    t.index ["created_by_id"], name: "index_quotations_on_created_by_id"
    t.index ["customer_id"], name: "index_quotations_on_customer_id"
    t.index ["payment_status"], name: "index_quotations_on_payment_status"
    t.index ["preferred_move_date"], name: "index_quotations_on_preferred_move_date"
    t.index ["public_share_token"], name: "index_quotations_on_public_share_token", unique: true
    t.index ["reference"], name: "index_quotations_on_reference", unique: true
    t.index ["selected_driver_offer_id"], name: "index_quotations_on_selected_driver_offer_id"
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

  add_foreign_key "accounting_transactions", "accounting_categories"
  add_foreign_key "accounting_transactions", "quotation_payments"
  add_foreign_key "accounting_transactions", "quotations"
  add_foreign_key "accounting_transactions", "users"
  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "blog_posts", "users", column: "author_id"
  add_foreign_key "cart_items", "carts"
  add_foreign_key "cart_items", "products"
  add_foreign_key "carts", "users"
  add_foreign_key "conversation_participants", "conversations"
  add_foreign_key "conversation_participants", "users"
  add_foreign_key "customer_invoices", "quotation_payments"
  add_foreign_key "customer_invoices", "quotations"
  add_foreign_key "customer_invoices", "users", column: "customer_id"
  add_foreign_key "driver_availabilities", "users", column: "driver_id"
  add_foreign_key "driver_offers", "quotations"
  add_foreign_key "driver_offers", "users", column: "driver_id"
  add_foreign_key "driver_profiles", "users"
  add_foreign_key "driver_wallet_entries", "quotations"
  add_foreign_key "driver_wallet_entries", "users", column: "approved_by_id"
  add_foreign_key "driver_wallet_entries", "users", column: "driver_id"
  add_foreign_key "material_order_items", "material_orders"
  add_foreign_key "material_order_items", "products"
  add_foreign_key "material_orders", "carts"
  add_foreign_key "material_orders", "users", column: "customer_id"
  add_foreign_key "messages", "conversations"
  add_foreign_key "messages", "users", column: "sender_id"
  add_foreign_key "notifications", "users"
  add_foreign_key "notifications", "users", column: "actor_id"
  add_foreign_key "payroll_runs", "users", column: "created_by_id"
  add_foreign_key "payslips", "payroll_runs"
  add_foreign_key "payslips", "users", column: "employee_id"
  add_foreign_key "products", "product_categories"
  add_foreign_key "quotation_documents", "quotations"
  add_foreign_key "quotation_items", "quotations"
  add_foreign_key "quotation_notes", "quotations"
  add_foreign_key "quotation_notes", "users"
  add_foreign_key "quotation_payments", "quotations"
  add_foreign_key "quotation_status_events", "quotations"
  add_foreign_key "quotation_status_events", "users"
  add_foreign_key "quotations", "driver_offers", column: "selected_driver_offer_id"
  add_foreign_key "quotations", "users", column: "assigned_driver_id"
  add_foreign_key "quotations", "users", column: "assigned_staff_id"
  add_foreign_key "quotations", "users", column: "created_by_id"
  add_foreign_key "quotations", "users", column: "customer_id"
  add_foreign_key "web_push_subscriptions", "users"
end
