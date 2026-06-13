class AccountingTransaction < ApplicationRecord
  TRANSACTION_TYPES = {
    income: "income",
    expense: "expense",
    salary: "salary",
    commission: "commission",
    loan: "loan",
    investment: "investment",
    refund: "refund",
    adjustment: "adjustment"
  }.freeze

  INCOME_TYPES = %w[income investment].freeze
  EXPENSE_TYPES = %w[expense salary commission loan refund].freeze

  belongs_to :accounting_category, optional: true
  belongs_to :user, optional: true
  belongs_to :quotation, optional: true
  belongs_to :quotation_payment, optional: true

  enum :transaction_type, TRANSACTION_TYPES, validate: true

  validates :amount_cents, numericality: { greater_than: 0 }
  validates :transaction_date, presence: true
  validates :quotation_payment_id, uniqueness: true, allow_nil: true

  scope :recent, -> { order(transaction_date: :desc, created_at: :desc) }
  scope :in_period, ->(start_date, end_date) { where(transaction_date: start_date..end_date) }
  scope :income, -> { where(transaction_type: INCOME_TYPES) }
  scope :expenses, -> { where(transaction_type: EXPENSE_TYPES) }

  def amount
    amount_cents.to_i / 100.0
  end

  def income?
    INCOME_TYPES.include?(transaction_type)
  end

  def expense?
    EXPENSE_TYPES.include?(transaction_type)
  end

  class << self
    def summary_for(scope: all, start_date: nil, end_date: nil)
      scope = scope.in_period(start_date, end_date) if start_date && end_date

      totals = scope.group(:transaction_type).sum(:amount_cents)
      income_total = totals.slice(*INCOME_TYPES).values.sum
      expense_total = totals.slice(*EXPENSE_TYPES).values.sum
      driver_cost_total = driver_cost_for(scope)

      {
        income_cents: income_total,
        driver_cost_cents: driver_cost_total,
        total_revenue_cents: income_total + driver_cost_total,
        expense_cents: expense_total,
        payroll_cents: totals.fetch("salary", 0) + totals.fetch("commission", 0),
        refund_cents: totals.fetch("refund", 0),
        loan_cents: totals.fetch("loan", 0),
        investment_cents: totals.fetch("investment", 0),
        net_profit_cents: income_total - expense_total,
        by_type: totals
      }
    end

    def driver_cost_for(scope = all)
      scope.income.includes(:quotation_payment).sum do |transaction|
        payment = transaction.quotation_payment
        next 0 if payment.blank?

        [payment.amount_cents.to_i - transaction.amount_cents.to_i, 0].max
      end
    end
  end
end
