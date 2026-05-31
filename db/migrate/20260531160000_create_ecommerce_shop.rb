class CreateEcommerceShop < ActiveRecord::Migration[8.0]
  def change
    create_table :product_categories, id: :uuid do |t|
      t.string :name, null: false
      t.string :slug, null: false
      t.text :description
      t.integer :position, null: false, default: 0

      t.timestamps
    end
    add_index :product_categories, :slug, unique: true

    create_table :products, id: :uuid do |t|
      t.references :product_category, type: :uuid, foreign_key: true
      t.string :name, null: false
      t.string :slug, null: false
      t.string :sku, null: false
      t.text :description
      t.integer :price_cents, null: false, default: 0
      t.integer :stock_quantity, null: false, default: 0
      t.string :status, null: false, default: "active"
      t.boolean :featured, null: false, default: false

      t.timestamps
    end
    add_index :products, :slug, unique: true
    add_index :products, :sku, unique: true
    add_index :products, :status

    create_table :carts, id: :uuid do |t|
      t.references :user, type: :uuid, foreign_key: true
      t.string :session_token

      t.timestamps
    end
    add_index :carts, :session_token, unique: true, where: "session_token IS NOT NULL"

    create_table :cart_items, id: :uuid do |t|
      t.references :cart, type: :uuid, null: false, foreign_key: true
      t.references :product, type: :uuid, null: false, foreign_key: true
      t.integer :quantity, null: false, default: 1
      t.integer :unit_price_cents, null: false, default: 0

      t.timestamps
    end
    add_index :cart_items, %i[cart_id product_id], unique: true

    create_table :material_orders, id: :uuid do |t|
      t.references :cart, type: :uuid, foreign_key: true
      t.references :customer, type: :uuid, foreign_key: { to_table: :users }
      t.string :order_number, null: false
      t.string :customer_email, null: false
      t.string :fulfillment_type, null: false, default: "delivery"
      t.string :status, null: false, default: "pending"
      t.string :payment_status, null: false, default: "unpaid"
      t.integer :subtotal_cents, null: false, default: 0
      t.integer :delivery_fee_cents, null: false, default: 0
      t.integer :total_cents, null: false, default: 0
      t.string :stripe_checkout_session_id
      t.string :stripe_payment_intent_id
      t.string :delivery_name
      t.string :delivery_phone
      t.text :delivery_address
      t.string :delivery_postcode
      t.date :preferred_date
      t.string :preferred_window
      t.text :collection_instructions
      t.text :customer_notes
      t.text :admin_notes
      t.datetime :paid_at

      t.timestamps
    end
    add_index :material_orders, :order_number, unique: true
    add_index :material_orders, :stripe_checkout_session_id, unique: true, where: "stripe_checkout_session_id IS NOT NULL"
    add_index :material_orders, :status
    add_index :material_orders, :payment_status

    create_table :material_order_items, id: :uuid do |t|
      t.references :material_order, type: :uuid, null: false, foreign_key: true
      t.references :product, type: :uuid, foreign_key: true
      t.string :product_name, null: false
      t.string :product_sku, null: false
      t.integer :quantity, null: false, default: 1
      t.integer :unit_price_cents, null: false, default: 0
      t.integer :line_total_cents, null: false, default: 0

      t.timestamps
    end
  end
end
