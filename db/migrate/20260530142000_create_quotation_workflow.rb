class CreateQuotationWorkflow < ActiveRecord::Migration[8.0]
  def change
    create_table :quotations, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.string :reference, null: false
      t.references :customer, null: false, foreign_key: { to_table: :users }, type: :uuid
      t.references :created_by, foreign_key: { to_table: :users }, type: :uuid
      t.references :assigned_staff, foreign_key: { to_table: :users }, type: :uuid
      t.string :status, null: false, default: "draft"
      t.string :move_size, null: false, default: "studio"
      t.string :service_level, null: false, default: "standard"
      t.date :preferred_move_date
      t.datetime :scheduled_at
      t.string :pickup_postcode
      t.string :delivery_postcode
      t.text :pickup_address, null: false
      t.text :delivery_address, null: false
      t.text :access_notes
      t.text :customer_notes
      t.integer :quoted_price_cents, null: false, default: 0
      t.integer :deposit_cents, null: false, default: 0
      t.string :payment_status, null: false, default: "unpaid"
      t.datetime :quoted_at
      t.datetime :accepted_at
      t.datetime :completed_at
      t.datetime :cancelled_at

      t.timestamps
    end

    add_index :quotations, :reference, unique: true
    add_index :quotations, :status
    add_index :quotations, :payment_status
    add_index :quotations, :preferred_move_date

    create_table :quotation_items, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.references :quotation, null: false, foreign_key: true, type: :uuid
      t.string :name, null: false
      t.integer :quantity, null: false, default: 1
      t.boolean :fragile, null: false, default: false
      t.text :notes

      t.timestamps
    end

    create_table :quotation_notes, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.references :quotation, null: false, foreign_key: true, type: :uuid
      t.references :user, foreign_key: true, type: :uuid
      t.text :content, null: false
      t.boolean :internal, null: false, default: true

      t.timestamps
    end

    create_table :quotation_payments, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.references :quotation, null: false, foreign_key: true, type: :uuid
      t.integer :amount_cents, null: false, default: 0
      t.string :payment_method, null: false, default: "manual"
      t.string :status, null: false, default: "recorded"
      t.date :paid_on
      t.string :reference
      t.text :notes

      t.timestamps
    end

    create_table :quotation_documents, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.references :quotation, null: false, foreign_key: true, type: :uuid
      t.string :title, null: false
      t.string :document_type, null: false, default: "other"
      t.string :url
      t.text :notes

      t.timestamps
    end

    create_table :quotation_status_events, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.references :quotation, null: false, foreign_key: true, type: :uuid
      t.references :user, foreign_key: true, type: :uuid
      t.string :from_status
      t.string :to_status, null: false
      t.text :note

      t.timestamps
    end
  end
end
