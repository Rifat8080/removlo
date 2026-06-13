class AddPayoutMethodToDriverWalletEntries < ActiveRecord::Migration[8.0]
  def change
    add_column :driver_wallet_entries, :payout_method, :string
  end
end
