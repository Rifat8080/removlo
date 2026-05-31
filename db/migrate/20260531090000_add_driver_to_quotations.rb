class AddDriverToQuotations < ActiveRecord::Migration[8.0]
  def change
    add_reference :quotations, :assigned_driver, foreign_key: { to_table: :users }, type: :uuid
  end
end
