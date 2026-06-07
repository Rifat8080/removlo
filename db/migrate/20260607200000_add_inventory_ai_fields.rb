class AddInventoryAiFields < ActiveRecord::Migration[8.0]
  def change
    change_table :quotation_inventory_estimates, bulk: true do |t|
      t.string :processing_status, default: "pending", null: false
      t.string :ai_provider
      t.string :ai_model
      t.jsonb :ai_raw_response, default: {}, null: false
      t.text :ai_error
      t.datetime :processed_at
    end
  end
end
