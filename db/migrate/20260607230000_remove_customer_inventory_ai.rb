class RemoveCustomerInventoryAi < ActiveRecord::Migration[8.0]
  def up
    execute <<~SQL.squish
      DELETE FROM active_storage_attachments
      WHERE record_type = 'QuotationInventoryEstimate'
    SQL

    drop_table :quotation_inventory_estimates, if_exists: true
  end

  def down
    create_table :quotation_inventory_estimates, id: :uuid do |t|
      t.references :quotation, null: false, foreign_key: true, type: :uuid, index: { unique: true }
      t.jsonb :estimated_inventory, default: [], null: false
      t.string :suggested_vehicle
      t.string :estimate_status, default: "pending", null: false
      t.text :admin_notes
      t.string :processing_status, default: "pending", null: false
      t.string :ai_provider
      t.string :ai_model
      t.jsonb :ai_raw_response, default: {}, null: false
      t.text :ai_error
      t.datetime :processed_at
      t.timestamps
    end
  end
end
