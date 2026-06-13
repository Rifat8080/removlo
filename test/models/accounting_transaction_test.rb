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

  test "paid salary transaction notifies linked beneficiary" do
    beneficiary = users(:staff)

    assert_difference -> { Notification.where(user: beneficiary, event_type: "accounting.salary_paid").count }, 1 do
      AccountingTransaction.create!(
        transaction_type: :salary,
        salary_payment_status: :paid,
        user: beneficiary,
        amount_cents: 125_00,
        transaction_date: Date.current,
        description: "June salary"
      )
    end
  end

  test "pending salary transaction notifies beneficiary when marked paid" do
    beneficiary = users(:staff)
    transaction = AccountingTransaction.create!(
      transaction_type: :salary,
      salary_payment_status: :pending,
      user: beneficiary,
      amount_cents: 125_00,
      transaction_date: Date.current,
      description: "June salary"
    )

    assert_no_difference -> { Notification.where(user: beneficiary, event_type: "accounting.salary_paid").count } do
      transaction.update!(description: "June salary pending")
    end

    assert_difference -> { Notification.where(user: beneficiary, event_type: "accounting.salary_paid").count }, 1 do
      transaction.update!(salary_payment_status: :paid)
    end
  end

  test "salary transaction requires linked beneficiary and payment status" do
    transaction = AccountingTransaction.new(
      transaction_type: :salary,
      amount_cents: 125_00,
      transaction_date: Date.current,
      description: "Salary without beneficiary"
    )

    assert_not transaction.valid?
    assert_includes transaction.errors[:user], "must be selected for salary payments"
    assert_includes transaction.errors[:salary_payment_status], "must be selected for salary payments"
  end
end
