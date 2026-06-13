require "test_helper"

class AccountingTransactionTest < ActiveSupport::TestCase
  test "summary total revenue adds driver cost back to margin income" do
    quotation = quotations(:marketplace_job)
    payment = quotation.quotation_payments.create!(
      amount_cents: quotation.quoted_price_cents,
      payment_method: "stripe",
      status: :recorded,
      paid_on: Date.current,
      reference: "SUMMARY-REV"
    )
    Accounting::SyncQuotationPayment.call(payment)

    transaction = AccountingTransaction.find_by!(quotation_payment: payment)
    summary = AccountingTransaction.summary_for(scope: AccountingTransaction.where(id: transaction.id))

    assert_equal quotation.admin_margin_cents, summary[:income_cents]
    assert_equal quotation.driver_cost_cents, summary[:driver_cost_cents]
    assert_equal quotation.quoted_price_cents, summary[:total_revenue_cents]
  end

  test "summary total revenue keeps manual income as revenue without driver cost" do
    transaction = AccountingTransaction.create!(
      transaction_type: :income,
      amount_cents: 12_345,
      transaction_date: Date.current,
      description: "Manual income",
      accounting_category: accounting_categories(:moving_services)
    )

    summary = AccountingTransaction.summary_for(scope: AccountingTransaction.where(id: transaction.id))

    assert_equal 12_345, summary[:income_cents]
    assert_equal 0, summary[:driver_cost_cents]
    assert_equal 12_345, summary[:total_revenue_cents]
  end
end
