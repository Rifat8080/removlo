class AddCustomerPhoneToQuotations < ActiveRecord::Migration[8.0]
  def change
    add_column :quotations, :customer_phone, :string
  end
end