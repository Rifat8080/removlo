class CreateMarketplaceWorkflow < ActiveRecord::Migration[8.0]
  def change
    create_table :driver_profiles, id: :uuid do |t|
      t.references :user, null: false, foreign_key: true, type: :uuid, index: { unique: true }
      t.string :vehicle_type, default: "luton_van", null: false
      t.string :service_areas, array: true, default: [], null: false
      t.decimal :rating, precision: 3, scale: 2, default: "5.0", null: false
      t.integer :completed_jobs_count, default: 0, null: false
      t.decimal :completion_rate, precision: 5, scale: 2, default: "100.0", null: false
      t.decimal :cancellation_rate, precision: 5, scale: 2, default: "0.0", null: false
      t.integer :late_arrivals_count, default: 0, null: false
      t.integer :revenue_generated_cents, default: 0, null: false
      t.timestamps
    end

    create_table :driver_availabilities, id: :uuid do |t|
      t.references :driver, null: false, foreign_key: { to_table: :users }, type: :uuid
      t.date :available_on, null: false
      t.string :status, default: "available", null: false
      t.text :notes
      t.timestamps
    end
    add_index :driver_availabilities, %i[driver_id available_on], unique: true

    create_table :quotation_broadcasts, id: :uuid do |t|
      t.references :quotation, null: false, foreign_key: true, type: :uuid
      t.references :created_by, null: false, foreign_key: { to_table: :users }, type: :uuid
      t.string :vehicle_types, array: true, default: [], null: false
      t.string :service_areas, array: true, default: [], null: false
      t.decimal :minimum_rating, precision: 3, scale: 2, default: "0.0", null: false
      t.boolean :require_available, default: true, null: false
      t.integer :drivers_notified_count, default: 0, null: false
      t.timestamps
    end

    create_table :driver_offers, id: :uuid do |t|
      t.references :quotation, null: false, foreign_key: true, type: :uuid
      t.references :driver, null: false, foreign_key: { to_table: :users }, type: :uuid
      t.integer :amount_cents, null: false
      t.string :status, default: "submitted", null: false
      t.decimal :score, precision: 8, scale: 4
      t.jsonb :score_breakdown, default: {}, null: false
      t.boolean :selected_by_admin, default: false, null: false
      t.timestamps
    end
    add_index :driver_offers, %i[quotation_id driver_id], unique: true

    create_table :driver_wallet_entries, id: :uuid do |t|
      t.references :driver, null: false, foreign_key: { to_table: :users }, type: :uuid
      t.references :quotation, foreign_key: true, type: :uuid
      t.references :approved_by, foreign_key: { to_table: :users }, type: :uuid
      t.string :entry_type, null: false
      t.string :status, default: "pending", null: false
      t.integer :amount_cents, null: false
      t.string :reference
      t.text :notes
      t.datetime :approved_at
      t.timestamps
    end

    create_table :quotation_inventory_estimates, id: :uuid do |t|
      t.references :quotation, null: false, foreign_key: true, type: :uuid, index: { unique: true }
      t.jsonb :estimated_inventory, default: [], null: false
      t.string :suggested_vehicle
      t.string :estimate_status, default: "pending", null: false
      t.text :admin_notes
      t.timestamps
    end

    change_table :quotations, bulk: true do |t|
      t.integer :driver_cost_cents, default: 0, null: false
      t.decimal :markup_percentage, precision: 5, scale: 2, default: "30.0", null: false
      t.integer :admin_margin_cents, default: 0, null: false
      t.string :vehicle_required, default: "luton_van"
      t.integer :expected_duration_hours
      t.string :property_type
      t.boolean :awaiting_driver_offers, default: false, null: false
      t.boolean :customer_details_released, default: false, null: false
      t.references :selected_driver_offer, foreign_key: { to_table: :driver_offers }, type: :uuid
    end

    change_table :quotation_payments, bulk: true do |t|
      t.string :stripe_checkout_session_id
      t.string :stripe_payment_intent_id
    end
    add_index :quotation_payments, :stripe_checkout_session_id, unique: true, where: "stripe_checkout_session_id IS NOT NULL"
  end
end
