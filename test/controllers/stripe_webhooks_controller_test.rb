require "test_helper"

class StripeWebhooksControllerTest < ActionDispatch::IntegrationTest
  test "quotation acceptance payment webhook records payment and accepts quote" do
    quotation = quotations(:marketplace_job)
    quotation.update!(deposit_cents: 0)
    payment = quotation.quotation_payments.create!(
      amount_cents: quotation.quoted_price_cents,
      payment_method: "stripe",
      status: :pending,
      paid_on: Date.current,
      reference: "FULL-WEBHOOK",
      stripe_checkout_session_id: "cs_full_accept"
    )

    without_webhook_secret do
      assert_difference -> { CustomerInvoice.where(status: "paid", quotation: quotation).count }, 1 do
        post "/stripe/webhook", params: webhook_payload("checkout.session.completed", payment, "quotation_acceptance", payment_intent: "pi_full_accept").to_json, headers: { "CONTENT_TYPE" => "application/json" }
      end
    end

    assert_response :success
    assert payment.reload.recorded?
    assert quotation.reload.accepted?
    assert quotation.paid?
  end

  test "quotation checkout failure webhook creates failed invoice without accepting quote" do
    quotation = quotations(:marketplace_job)
    payment = quotation.quotation_payments.create!(
      amount_cents: quotation.quoted_price_cents,
      payment_method: "stripe",
      status: :pending,
      paid_on: Date.current,
      reference: "FULL-FAILED",
      stripe_checkout_session_id: "cs_full_failed"
    )

    without_webhook_secret do
      assert_difference -> { CustomerInvoice.where(status: "failed", quotation: quotation).count }, 1 do
        post "/stripe/webhook", params: webhook_payload("checkout.session.expired", payment, "quotation_acceptance").to_json, headers: { "CONTENT_TYPE" => "application/json" }
      end
    end

    assert_response :success
    assert payment.reload.failed?
    assert_equal "quoted", quotation.reload.status
  end

  test "quotation payment intent failure webhook creates failed invoice" do
    quotation = quotations(:marketplace_job)
    payment = quotation.quotation_payments.create!(
      amount_cents: quotation.quoted_price_cents,
      payment_method: "stripe",
      status: :pending,
      paid_on: Date.current,
      reference: "FULL-PI-FAILED"
    )

    without_webhook_secret do
      assert_difference -> { CustomerInvoice.where(status: "failed", quotation: quotation).count }, 1 do
        post "/webhooks/stripe", params: payment_intent_payload("payment_intent.payment_failed", payment, payment_intent: "pi_failed").to_json, headers: { "CONTENT_TYPE" => "application/json" }
      end
    end

    assert_response :success
    assert payment.reload.failed?
    assert_equal "pi_failed", payment.stripe_payment_intent_id
  end

  test "quotation refund webhook creates refunded invoice" do
    quotation = quotations(:marketplace_job)
    payment = quotation.quotation_payments.create!(
      amount_cents: quotation.quoted_price_cents,
      payment_method: "stripe",
      status: :recorded,
      paid_on: Date.current,
      reference: "FULL-REFUND",
      stripe_payment_intent_id: "pi_refunded"
    )

    assert CustomerInvoice.where(status: "paid", quotation: quotation, quotation_payment: payment).exists?

    without_webhook_secret do
      assert_difference -> { CustomerInvoice.where(status: "refunded", quotation: quotation).count }, 1 do
        post "/webhooks/stripe", params: refund_payload("refund.created", payment, payment_intent: "pi_refunded").to_json, headers: { "CONTENT_TYPE" => "application/json" }
      end
    end

    assert_response :success
    assert payment.reload.refunded?
    assert CustomerInvoice.where(status: "refunded", quotation: quotation, quotation_payment: payment).exists?
  end

  test "duplicate Stripe refund webhooks do not create duplicate refund notifications" do
    quotation = quotations(:marketplace_job)
    payment = quotation.quotation_payments.create!(
      amount_cents: quotation.quoted_price_cents,
      payment_method: "stripe",
      status: :recorded,
      paid_on: Date.current,
      reference: "FULL-REFUND-DUP",
      stripe_payment_intent_id: "pi_refunded_duplicate"
    )
    Accounting::SyncQuotationPayment.call(payment)
    invoice = CustomerInvoice.find_by!(quotation_payment: payment)

    without_webhook_secret do
      assert_difference -> { Notification.where(event_type: "accounting.refund", notifiable: invoice).count }, 1 do
        post "/webhooks/stripe", params: refund_payload("refund.created", payment, payment_intent: "pi_refunded_duplicate").to_json, headers: { "CONTENT_TYPE" => "application/json" }
        post "/webhooks/stripe", params: refund_payload("refund.updated", payment, payment_intent: "pi_refunded_duplicate").to_json, headers: { "CONTENT_TYPE" => "application/json" }
        post "/webhooks/stripe", params: refund_payload("charge.refunded", payment, payment_intent: "pi_refunded_duplicate").to_json, headers: { "CONTENT_TYPE" => "application/json" }
        post "/webhooks/stripe", params: refund_payload("charge.refund.updated", payment, payment_intent: "pi_refunded_duplicate").to_json, headers: { "CONTENT_TYPE" => "application/json" }
      end
    end

    assert payment.reload.refunded?
    assert_equal 1, Notification.where(event_type: "accounting.refund", notifiable: invoice).count
  end

  test "account updated webhook syncs driver stripe payout status" do
    profile = driver_profiles(:driver_a_profile)
    profile.update!(stripe_account_id: "acct_driver_a", stripe_onboarding_status: "pending", stripe_payouts_enabled: false)

    without_webhook_secret do
      post "/webhooks/stripe", params: account_updated_payload("acct_driver_a", payouts_enabled: true, charges_enabled: true, details_submitted: true).to_json, headers: { "CONTENT_TYPE" => "application/json" }
    end

    assert_response :success
    profile.reload
    assert profile.stripe_payouts_enabled
    assert profile.stripe_charges_enabled
    assert_equal "complete", profile.stripe_onboarding_status
  end

  test "transfer reversed webhook reopens withdrawal request for admin action" do
    driver = users(:driver_a)
    entry = driver.driver_wallet_entries.create!(
      entry_type: :withdrawal_request,
      status: :withdrawn,
      amount_cents: -75_00,
      reference: "WITHDRAW-REVERSED",
      stripe_transfer_id: "tr_reversed_test",
      stripe_transfer_status: "paid"
    )

    without_webhook_secret do
      assert_difference -> { Notification.where(event_type: "driver_wallet.transfer_failed", notifiable: entry).count }, 1 do
        post "/webhooks/stripe", params: transfer_payload("transfer.reversed", "tr_reversed_test").to_json, headers: { "CONTENT_TYPE" => "application/json" }
      end
    end

    assert_response :success
    entry.reload
    assert_equal "available", entry.status
    assert_equal "reversed", entry.stripe_transfer_status
  end

  test "production webhook fails closed when webhook secret is missing" do
    quotation = quotations(:marketplace_job)
    payment = quotation.quotation_payments.create!(
      amount_cents: quotation.quoted_price_cents,
      payment_method: "stripe",
      status: :pending,
      paid_on: Date.current,
      reference: "FULL-PROD-SECRET",
      stripe_checkout_session_id: "cs_prod_secret"
    )
    webhook_secret = ENV["STRIPE_WEBHOOK_SECRET"]
    ENV.delete("STRIPE_WEBHOOK_SECRET")

    Rails.env.stub(:production?, true) do
      post "/webhooks/stripe", params: webhook_payload("checkout.session.completed", payment, "quotation_acceptance").to_json, headers: { "CONTENT_TYPE" => "application/json" }
    end

    assert_response :service_unavailable
  ensure
    ENV["STRIPE_WEBHOOK_SECRET"] = webhook_secret if webhook_secret
  end

  private

  def without_webhook_secret
    webhook_secret = ENV["STRIPE_WEBHOOK_SECRET"]
    ENV.delete("STRIPE_WEBHOOK_SECRET")
    yield
  ensure
    ENV["STRIPE_WEBHOOK_SECRET"] = webhook_secret if webhook_secret
  end

  def webhook_payload(type, payment, payment_kind, payment_intent: "pi_test")
    {
      type: type,
      data: {
        object: {
          id: payment.stripe_checkout_session_id,
          payment_intent: payment_intent,
          customer_email: payment.quotation.customer.email,
          metadata: {
            quotation_id: payment.quotation_id,
            quotation_payment_id: payment.id,
            payment_kind: payment_kind
          }
        }
      }
    }
  end

  def payment_intent_payload(type, payment, payment_intent:)
    {
      type: type,
      data: {
        object: {
          id: payment_intent,
          metadata: {
            quotation_id: payment.quotation_id,
            quotation_payment_id: payment.id,
            payment_kind: "quotation_acceptance"
          }
        }
      }
    }
  end

  def refund_payload(type, payment, payment_intent:)
    {
      type: type,
      data: {
        object: {
          id: "re_test",
          payment_intent: payment_intent,
          metadata: {
            quotation_id: payment.quotation_id,
            quotation_payment_id: payment.id,
            payment_kind: "quotation_acceptance"
          }
        }
      }
    }
  end

  def account_updated_payload(account_id, payouts_enabled:, charges_enabled:, details_submitted:)
    {
      type: "account.updated",
      data: {
        object: {
          id: account_id,
          payouts_enabled: payouts_enabled,
          charges_enabled: charges_enabled,
          details_submitted: details_submitted
        }
      }
    }
  end

  def transfer_payload(type, transfer_id)
    {
      type: type,
      data: {
        object: {
          id: transfer_id
        }
      }
    }
  end
end
