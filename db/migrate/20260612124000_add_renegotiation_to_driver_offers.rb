class AddRenegotiationToDriverOffers < ActiveRecord::Migration[8.0]
  def change
    add_column :driver_offers, :renegotiation_price_cents, :integer
    add_column :driver_offers, :renegotiation_status, :string, default: "none", null: false
    add_column :driver_offers, :renegotiation_requested_at, :datetime
    add_column :driver_offers, :renegotiation_responded_at, :datetime
  end
end
