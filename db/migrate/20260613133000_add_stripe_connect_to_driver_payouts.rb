class AddStripeConnectToDriverPayouts < ActiveRecord::Migration[8.0]
  def change
    change_table :driver_profiles, bulk: true do |t|
      t.string :stripe_account_id
      t.string :stripe_onboarding_status, null: false, default: "not_started"
      t.boolean :stripe_charges_enabled, null: false, default: false
      t.boolean :stripe_payouts_enabled, null: false, default: false
    end
    add_index :driver_profiles, :stripe_account_id, unique: true, where: "stripe_account_id IS NOT NULL"

    change_table :driver_wallet_entries, bulk: true do |t|
      t.string :stripe_transfer_id
      t.string :stripe_transfer_status
      t.text :stripe_transfer_error
    end
    add_index :driver_wallet_entries, :stripe_transfer_id, unique: true, where: "stripe_transfer_id IS NOT NULL"
  end
end
