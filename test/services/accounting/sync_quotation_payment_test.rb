require "test_helper"

class Accounting::SyncQuotationPaymentTest < ActiveSupport::TestCase
  test "recorded payment creates full customer invoice and margin-only income" do
    quotation = quotations(:marketplace_job)
    payment = quotation.quotation_payments.create!(
      amount_cents: quotation.quoted_price_cents,
      payment_method: "stripe",
      status: :recorded,
      paid_on: Date.current,
      reference: "FULL-MARGIN"
    )

    Accounting::SyncQuotationPayment.call(payment)

    invoice = CustomerInvoice.find_by!(quotation_payment: payment)
    transaction = AccountingTransaction.find_by!(quotation_payment: payment)

    assert_equal quotation.quoted_price_cents, invoice.amount_cents
    assert_equal "paid", invoice.status
    assert_equal quotation.admin_margin_cents, transaction.amount_cents
    assert_equal "income", transaction.transaction_type
  end

  test "partial payments allocate margin proportionally without exceeding total margin" do
    quotation = quotations(:marketplace_job)
    deposit = quotation.quotation_payments.create!(
      amount_cents: quotation.deposit_cents,
      payment_method: "stripe",
      status: :recorded,
      paid_on: Date.current,
      reference: "DEP-MARGIN"
    )
    balance = quotation.quotation_payments.create!(
      amount_cents: quotation.quoted_price_cents - quotation.deposit_cents,
      payment_method: "stripe",
      status: :recorded,
      paid_on: Date.current,
      reference: "BAL-MARGIN"
    )

    Accounting::SyncQuotationPayment.call(deposit)
    Accounting::SyncQuotationPayment.call(balance)

    deposit_income = AccountingTransaction.find_by!(quotation_payment: deposit)
    balance_income = AccountingTransaction.find_by!(quotation_payment: balance)

    assert_equal 2_308, deposit_income.amount_cents
    assert_equal 12_692, balance_income.amount_cents
    assert_equal quotation.admin_margin_cents, deposit_income.amount_cents + balance_income.amount_cents
    assert_equal quotation.deposit_cents, CustomerInvoice.find_by!(quotation_payment: deposit).amount_cents
    assert_equal balance.amount_cents, CustomerInvoice.find_by!(quotation_payment: balance).amount_cents
  end

  test "refund accounting reverses recognized margin only" do
    quotation = quotations(:marketplace_job)
    payment = quotation.quotation_payments.create!(
      amount_cents: quotation.quoted_price_cents,
      payment_method: "stripe",
      status: :recorded,
      paid_on: Date.current,
      reference: "REFUND-MARGIN"
    )
    Accounting::SyncQuotationPayment.call(payment)
    payment.update!(status: :refunded)

    Accounting::SyncQuotationPayment.call(payment)

    refund_transaction = AccountingTransaction.refund.find_by!(quotation_payment: payment)
    assert_equal quotation.admin_margin_cents, refund_transaction.amount_cents
    assert_equal quotation.quoted_price_cents, CustomerInvoice.find_by!(quotation_payment: payment).amount_cents
  end
end
