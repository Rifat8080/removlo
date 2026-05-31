class CreateAccountingSystem < ActiveRecord::Migration[8.0]
  def change
    create_table :accounting_categories, id: :uuid do |t|
      t.string :name, null: false
      t.string :slug, null: false
      t.string :category_type, null: false, default: "expense"
      t.text :description

      t.timestamps
    end
    add_index :accounting_categories, :slug, unique: true

    create_table :accounting_transactions, id: :uuid do |t|
      t.references :accounting_category, type: :uuid, foreign_key: true
      t.references :user, type: :uuid, foreign_key: true
      t.references :quotation, type: :uuid, foreign_key: true
      t.references :quotation_payment, type: :uuid, foreign_key: true
      t.string :transaction_type, null: false
      t.integer :amount_cents, null: false, default: 0
      t.date :transaction_date, null: false
      t.string :description
      t.string :vendor_payee
      t.string :payment_method
      t.string :reference

      t.timestamps
    end
    add_index :accounting_transactions, %i[transaction_type transaction_date], name: "index_accounting_transactions_on_type_and_date"
    add_index :accounting_transactions, :quotation_payment_id, unique: true, where: "quotation_payment_id IS NOT NULL", name: "index_accounting_transactions_on_quotation_payment_unique"

    create_table :customer_invoices, id: :uuid do |t|
      t.string :invoice_number, null: false
      t.string :invoice_type, null: false, default: "standard"
      t.references :customer, type: :uuid, null: false, foreign_key: { to_table: :users }
      t.references :quotation, type: :uuid, foreign_key: true
      t.references :quotation_payment, type: :uuid, foreign_key: true
      t.integer :amount_cents, null: false, default: 0
      t.string :status, null: false, default: "issued"
      t.date :issued_on, null: false
      t.date :settled_on
      t.text :notes

      t.timestamps
    end
    add_index :customer_invoices, :invoice_number, unique: true
    add_index :customer_invoices, :quotation_payment_id, unique: true, where: "quotation_payment_id IS NOT NULL", name: "index_customer_invoices_on_quotation_payment_unique"

    create_table :payroll_runs, id: :uuid do |t|
      t.date :period_start, null: false
      t.date :period_end, null: false
      t.string :status, null: false, default: "draft"
      t.text :notes
      t.references :created_by, type: :uuid, foreign_key: { to_table: :users }

      t.timestamps
    end

    create_table :payslips, id: :uuid do |t|
      t.references :payroll_run, type: :uuid, null: false, foreign_key: true
      t.references :employee, type: :uuid, null: false, foreign_key: { to_table: :users }
      t.string :employee_role, null: false
      t.integer :base_salary_cents, null: false, default: 0
      t.integer :bonus_cents, null: false, default: 0
      t.integer :commission_cents, null: false, default: 0
      t.integer :deductions_cents, null: false, default: 0
      t.integer :net_pay_cents, null: false, default: 0
      t.date :payment_date
      t.text :notes

      t.timestamps
    end
    add_index :payslips, %i[payroll_run_id employee_id], unique: true
  end
end
