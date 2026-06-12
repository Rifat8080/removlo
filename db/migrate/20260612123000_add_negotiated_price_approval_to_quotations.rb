class AddNegotiatedPriceApprovalToQuotations < ActiveRecord::Migration[8.0]
  def change
    add_column :quotations, :pending_quoted_price_cents, :integer
    add_column :quotations, :negotiated_price_approval_status, :string, default: "none", null: false
    add_column :quotations, :negotiated_price_requested_at, :datetime
    add_column :quotations, :negotiated_price_approved_at, :datetime
    add_reference :quotations, :negotiated_price_requested_by, type: :uuid, foreign_key: { to_table: :users }
    add_reference :quotations, :negotiated_price_approved_by, type: :uuid, foreign_key: { to_table: :users }
  end
end
