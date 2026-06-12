class AddRouteEstimatesAndDriverLocations < ActiveRecord::Migration[8.0]
  def change
    change_table :quotations, bulk: true do |t|
      t.decimal :pickup_latitude, precision: 10, scale: 7
      t.decimal :pickup_longitude, precision: 10, scale: 7
      t.decimal :delivery_latitude, precision: 10, scale: 7
      t.decimal :delivery_longitude, precision: 10, scale: 7
      t.integer :route_distance_meters
      t.integer :route_duration_seconds
      t.string :route_summary
      t.text :route_polyline
      t.datetime :route_estimated_at
      t.string :route_estimate_error
    end

    create_table :driver_locations, id: :uuid do |t|
      t.references :quotation, null: false, foreign_key: true, type: :uuid
      t.references :driver, null: false, foreign_key: { to_table: :users }, type: :uuid
      t.decimal :latitude, null: false, precision: 10, scale: 7
      t.decimal :longitude, null: false, precision: 10, scale: 7
      t.decimal :accuracy_meters, precision: 8, scale: 2
      t.decimal :heading, precision: 6, scale: 2
      t.decimal :speed_mps, precision: 8, scale: 2
      t.integer :eta_seconds
      t.string :eta_destination
      t.datetime :recorded_at, null: false

      t.timestamps
    end

    add_index :driver_locations, [:quotation_id, :recorded_at]
  end
end
