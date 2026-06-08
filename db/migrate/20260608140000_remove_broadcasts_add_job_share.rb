class RemoveBroadcastsAddJobShare < ActiveRecord::Migration[8.0]
  def up
    drop_table :quotation_broadcasts, if_exists: true

    add_column :quotations, :public_share_token, :string
    add_index :quotations, :public_share_token, unique: true

    execute <<~SQL.squish
      UPDATE quotations
      SET public_share_token = encode(gen_random_bytes(16), 'hex')
      WHERE public_share_token IS NULL
    SQL

    change_column_null :quotations, :public_share_token, false
  end

  def down
    remove_index :quotations, :public_share_token
    remove_column :quotations, :public_share_token

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
  end
end
