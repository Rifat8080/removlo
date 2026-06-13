require "test_helper"

class QuotationDepositsControllerTest < ActionDispatch::IntegrationTest
  test "customer can pay deposit in dev mode" do
    sign_in users(:customer)
    quotation = quotations(:marketplace_job)
    quotation.update!(status: "quoted", deposit_cents: 10_000)

    stripe_key = ENV["STRIPE_SECRET_KEY"]
    ENV.delete("STRIPE_SECRET_KEY")
    post deposit_checkout_quotation_path(quotation)

    assert_redirected_to quotation_path(quotation)
    quotation.reload
    assert quotation.deposit_protected?
    assert quotation.accepted?
  ensure
    ENV["STRIPE_SECRET_KEY"] = stripe_key if stripe_key
  end

  test "customer can pay remaining quotation balance in dev mode" do
    sign_in users(:customer)
    quotation = quotations(:accepted_job)
    quotation.quotation_payments.create!(
      amount_cents: quotation.deposit_cents,
      payment_method: "stripe",
      status: :recorded,
      paid_on: Date.current,
      reference: "DEP-TEST"
    )
    quotation.reload
    assert quotation.remaining_balance_cents.positive?

    stripe_key = ENV["STRIPE_SECRET_KEY"]
    ENV.delete("STRIPE_SECRET_KEY")
    post balance_checkout_quotation_path(quotation)

    assert_redirected_to quotation_path(quotation)
    quotation.reload
    assert quotation.paid?
    assert_equal 0, quotation.remaining_balance_cents
  ensure
    ENV["STRIPE_SECRET_KEY"] = stripe_key if stripe_key
  end

  test "customer can pay full quote to accept when deposit is not set" do
    sign_in users(:customer)
    quotation = quotations(:marketplace_job)
    quotation.update!(status: "quoted", deposit_cents: 0)

    stripe_key = ENV["STRIPE_SECRET_KEY"]
    ENV.delete("STRIPE_SECRET_KEY")
    post deposit_checkout_quotation_path(quotation)

    assert_redirected_to quotation_path(quotation)
    quotation.reload
    assert quotation.accepted?
    assert quotation.paid?
    assert_equal 0, quotation.remaining_balance_cents
  ensure
    ENV["STRIPE_SECRET_KEY"] = stripe_key if stripe_key
  end

  test "Stripe success return records payment and accepts quotation" do
    sign_in users(:customer)
    quotation = quotations(:marketplace_job)
    quotation.update!(status: "quoted", deposit_cents: 10_000)
    payment = quotation.quotation_payments.create!(
      amount_cents: quotation.deposit_cents,
      payment_method: "stripe",
      status: :pending,
      paid_on: Date.current,
      reference: "DEP-SUCCESS",
      stripe_checkout_session_id: "cs_paid_return"
    )
    stripe_session = Struct.new(:id, :payment_intent, :payment_status).new("cs_paid_return", "pi_paid_return", "paid")

    Stripe::Checkout::Session.stub(:retrieve, stripe_session) do
      get deposit_success_quotation_path(quotation, session_id: "cs_paid_return")
    end

    assert_redirected_to quotation_path(quotation)
    assert payment.reload.recorded?
    assert quotation.reload.accepted?
    assert quotation.deposit_protected?
  end

  test "Stripe success return does not accept quotation when session is not paid" do
    sign_in users(:customer)
    quotation = quotations(:marketplace_job)
    quotation.update!(status: "quoted", deposit_cents: 10_000)
    payment = quotation.quotation_payments.create!(
      amount_cents: quotation.deposit_cents,
      payment_method: "stripe",
      status: :pending,
      paid_on: Date.current,
      reference: "DEP-UNPAID",
      stripe_checkout_session_id: "cs_unpaid_return"
    )
    stripe_session = Struct.new(:id, :payment_intent, :payment_status).new("cs_unpaid_return", "pi_unpaid_return", "unpaid")

    Stripe::Checkout::Session.stub(:retrieve, stripe_session) do
      get deposit_success_quotation_path(quotation, session_id: "cs_unpaid_return")
    end

    assert_redirected_to quotation_path(quotation)
    assert payment.reload.pending?
    assert_equal "quoted", quotation.reload.status
  end

  test "paid quotation success return does not show verification failure" do
    sign_in users(:customer)
    quotation = quotations(:marketplace_job)
    quotation.update!(status: "accepted", deposit_cents: 0)
    quotation.quotation_payments.create!(
      amount_cents: quotation.quoted_price_cents,
      payment_method: "stripe",
      status: :recorded,
      paid_on: Date.current,
      reference: "FULL-PAID",
      stripe_payment_intent_id: "pi_already_paid"
    )
    quotation.reload
    assert quotation.paid?

    Stripe::Checkout::Session.stub(:retrieve, ->(_session_id) { raise Stripe::InvalidRequestError.new("No such checkout.session", nil) }) do
      get deposit_success_quotation_path(quotation, session_id: "cs_stale")
    end

    assert_redirected_to quotation_path(quotation)
    assert_equal "Payment already received. Your quote is accepted and protected.", flash[:notice]
    assert_nil flash[:alert]
  end

  test "production checkout does not simulate payment when Stripe key is missing" do
    sign_in users(:customer)
    quotation = quotations(:marketplace_job)
    quotation.update!(status: "quoted", deposit_cents: 0)
    stripe_key = ENV["STRIPE_SECRET_KEY"]
    ENV.delete("STRIPE_SECRET_KEY")

    Rails.env.stub(:production?, true) do
      post deposit_checkout_quotation_path(quotation)
    end

    assert_redirected_to quotation_path(quotation)
    assert_equal "quoted", quotation.reload.status
    assert quotation.quotation_payments.pending.exists?
    assert_not quotation.paid?
  ensure
    ENV["STRIPE_SECRET_KEY"] = stripe_key if stripe_key
  end

  test "cancelled Stripe checkout creates failed invoice and keeps quote payable" do
    sign_in users(:customer)
    quotation = quotations(:marketplace_job)
    quotation.update!(deposit_cents: 0)
    payment = quotation.quotation_payments.create!(
      amount_cents: quotation.quoted_price_cents,
      payment_method: "stripe",
      status: :pending,
      paid_on: Date.current,
      reference: "FULL-CANCEL"
    )

    assert_difference -> { CustomerInvoice.where(status: "failed", quotation: quotation).count }, 1 do
      get deposit_cancel_quotation_path(quotation, payment_id: payment.id)
    end

    assert_redirected_to quotation_path(quotation)
    assert payment.reload.failed?
    assert_equal "quoted", quotation.reload.status

    get quotation_path(quotation)
    assert_response :success
    assert_match "Pay full quote to accept", response.body
  end
end
