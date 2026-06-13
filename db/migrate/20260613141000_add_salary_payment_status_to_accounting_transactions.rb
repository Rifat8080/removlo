class AddSalaryPaymentStatusToAccountingTransactions < ActiveRecord::Migration[8.0]
  def change
    add_column :accounting_transactions, :salary_payment_status, :string
  end
end
