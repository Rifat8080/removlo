require "ostruct"

class StripeWebhooksController < ApplicationController
  skip_before_action :verify_authenticity_token

  def create
    payload = request.body.read
    sig_header = request.env["HTTP_STRIPE_SIGNATURE"]
    endpoint_secret = ENV["STRIPE_WEBHOOK_SECRET"]

    if Rails.env.production? && endpoint_secret.blank?
      Rails.logger.error("[StripeWebhooksController] STRIPE_WEBHOOK_SECRET is missing in production")
      head :service_unavailable
      return
    end

    event =
      if endpoint_secret.present?
        Stripe::Webhook.construct_event(payload, sig_header, endpoint_secret)
      else
        JSON.parse(payload, object_class: OpenStruct)
      end

    handle_event(event)
    head :ok
  rescue JSON::ParserError, Stripe::SignatureVerificationError
    head :bad_request
  end

  private

  def handle_event(event)
    type = event.is_a?(Hash) ? event["type"] : event.type

    if type.in?(%w[checkout.session.completed checkout.session.expired checkout.session.async_payment_failed])
      session = event.is_a?(Hash) ? event.dig("data", "object") : event.data.object
      session_id = session.is_a?(Hash) ? session["id"] : session.id
      metadata = session.is_a?(Hash) ? session["metadata"] : session.metadata
      payment_intent = session.is_a?(Hash) ? session["payment_intent"] : session.payment_intent
      customer_email = session.is_a?(Hash) ? session["customer_email"] : session.customer_email
      payment_kind = metadata.is_a?(Hash) ? metadata["payment_kind"] : metadata&.payment_kind

      if payment_kind.in?(%w[quotation_deposit quotation_balance quotation_acceptance])
        type == "checkout.session.completed" ? finalize_quotation_payment(session_id, payment_intent, metadata, payment_kind) : fail_quotation_payment(session_id, metadata)
        return
      end

      return unless type == "checkout.session.completed"

      order = MaterialOrder.find_by(stripe_checkout_session_id: session_id) ||
              MaterialOrder.find_by(id: metadata_value(metadata, "material_order_id"))
      return if order.blank? || order.payment_paid?
      return unless paid_material_order_session?(session, order)

      order.mark_paid!(stripe_payment_intent_id: payment_intent)
      clear_cart_for(order)
      link_guest_order_customer(order, customer_email || order.customer_email)
      return
    end

    if type == "payment_intent.payment_failed"
      payment_intent = event.is_a?(Hash) ? event.dig("data", "object") : event.data.object
      metadata = payment_intent.is_a?(Hash) ? payment_intent["metadata"] : payment_intent.metadata
      fail_quotation_payment(nil, metadata, payment_intent_id: payment_intent.is_a?(Hash) ? payment_intent["id"] : payment_intent.id)
      return
    end

    if type.in?(%w[refund.created refund.updated charge.refunded charge.refund.updated])
      stripe_object = event.is_a?(Hash) ? event.dig("data", "object") : event.data.object
      refund_quotation_payment(stripe_object)
      return
    end

    if type == "account.updated"
      account = event.is_a?(Hash) ? event.dig("data", "object") : event.data.object
      sync_driver_stripe_account(account)
      return
    end

    if type.in?(%w[transfer.reversed transfer.failed])
      stripe_object = event.is_a?(Hash) ? event.dig("data", "object") : event.data.object
      handle_transfer_failure(stripe_object, type)
    end
  end

  def finalize_quotation_payment(session_id, payment_intent, metadata, payment_kind)
    payment = QuotationPayment.find_by(stripe_checkout_session_id: session_id)
    payment ||= QuotationPayment.find_by(id: metadata.is_a?(Hash) ? metadata["quotation_payment_id"] : metadata&.quotation_payment_id)
    return if payment.blank? || payment.recorded?

    payment.update!(
      status: :recorded,
      stripe_payment_intent_id: payment_intent,
      stripe_checkout_session_id: session_id
    )
    Accounting::SyncQuotationPayment.call(payment)
    payment.quotation.sync_payment_status!
    accept_quotation_after_payment(payment.quotation) if payment_kind.in?(%w[quotation_deposit quotation_acceptance])
  end

  def fail_quotation_payment(session_id, metadata, payment_intent_id: nil)
    payment = QuotationPayment.find_by(stripe_checkout_session_id: session_id)
    payment ||= QuotationPayment.find_by(id: metadata.is_a?(Hash) ? metadata["quotation_payment_id"] : metadata&.quotation_payment_id)
    return if payment.blank? || payment.recorded? || payment.failed?

    payment.update!(
      status: :failed,
      stripe_payment_intent_id: payment_intent_id || payment.stripe_payment_intent_id,
      notes: "Stripe payment failed or checkout expired."
    )
    Accounting::SyncQuotationPayment.call(payment)
  end

  def refund_quotation_payment(stripe_object)
    payment_intent_id = stripe_value(stripe_object, "payment_intent")
    metadata = stripe_value(stripe_object, "metadata")
    payment = QuotationPayment.find_by(stripe_payment_intent_id: payment_intent_id)
    payment ||= QuotationPayment.find_by(id: metadata_value(metadata, "quotation_payment_id"))
    return if payment.blank? || payment.refunded?

    payment.update!(
      status: :refunded,
      notes: [payment.notes, "Stripe payment was refunded."].compact_blank.join(" ")
    )
    Accounting::SyncQuotationPayment.call(payment)
    payment.quotation.sync_payment_status!
  end

  def accept_quotation_after_payment(quotation)
    return if quotation.accepted?

    quotation.transition_to!(:accepted, actor: quotation.customer, note: "Customer accepted the quote after Stripe payment")
    ::ActivityNotifier.call(
      recipients: User.operators,
      event_type: "quotation.customer_activity",
      title: "Quote accepted",
      body: "#{quotation.customer.email} accepted #{quotation.reference} after Stripe payment.",
      url: admin_quotation_path(quotation),
      actor: quotation.customer,
      notifiable: quotation
    )
  end

  def clear_cart_for(order)
    cart = order.cart || Cart.find_by(id: order.cart_id)
    cart&.cart_items&.destroy_all
  end

  def link_guest_order_customer(order, email)
    return if order.customer.present?

    user = User.find_by(email: email)
    order.update!(customer: user) if user&.customer?
  end

  def paid_material_order_session?(session, order)
    stripe_value(session, "payment_status") == "paid" &&
      stripe_value(session, "id") == order.stripe_checkout_session_id &&
      metadata_value(stripe_value(session, "metadata"), "material_order_id").to_s == order.id.to_s &&
      stripe_value(session, "amount_total").to_i == order.total_cents.to_i
  end

  def stripe_value(stripe_object, key)
    return stripe_object[key] if stripe_object.is_a?(Hash)
    return stripe_object.public_send(key) if stripe_object.respond_to?(key)

    nil
  end

  def metadata_value(metadata, key)
    return metadata[key] if metadata.is_a?(Hash)
    return metadata.public_send(key) if metadata&.respond_to?(key)

    nil
  end

  def sync_driver_stripe_account(account)
    account_id = stripe_value(account, "id")
    profile = DriverProfile.find_by(stripe_account_id: account_id)
    return if profile.blank?

    profile.sync_stripe_account!(account)
  end

  def handle_transfer_failure(stripe_object, type)
    transfer_id = stripe_value(stripe_object, "id")
    entry = DriverWalletEntry.find_by(stripe_transfer_id: transfer_id)
    return if entry.blank? || !entry.withdrawn?

    message = type == "transfer.reversed" ? "Stripe transfer was reversed." : "Stripe transfer failed."
    entry.mark_transfer_reversed!(message: message)

    ::ActivityNotifier.call(
      recipients: User.where(role: "admin"),
      event_type: "driver_wallet.transfer_failed",
      title: "Driver payout transfer failed",
      body: "#{entry.driver.email}'s transfer of £#{'%.2f' % (entry.amount_cents.abs / 100.0)} needs attention.",
      url: admin_wallet_payouts_path,
      notifiable: entry
    )
  end
end
