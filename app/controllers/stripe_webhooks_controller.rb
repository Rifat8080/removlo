class StripeWebhooksController < ApplicationController
  skip_before_action :verify_authenticity_token

  def create
    payload = request.body.read
    sig_header = request.env["HTTP_STRIPE_SIGNATURE"]
    endpoint_secret = ENV["STRIPE_WEBHOOK_SECRET"]

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
    return unless type == "checkout.session.completed"

    session = event.is_a?(Hash) ? event.dig("data", "object") : event.data.object
    session_id = session.is_a?(Hash) ? session["id"] : session.id
    metadata = session.is_a?(Hash) ? session["metadata"] : session.metadata
    payment_intent = session.is_a?(Hash) ? session["payment_intent"] : session.payment_intent
    customer_email = session.is_a?(Hash) ? session["customer_email"] : session.customer_email
    payment_kind = metadata.is_a?(Hash) ? metadata["payment_kind"] : metadata&.payment_kind

    if payment_kind == "quotation_deposit"
      finalize_quotation_deposit(session_id, payment_intent, metadata)
      return
    end

    order = MaterialOrder.find_by(stripe_checkout_session_id: session_id) ||
            MaterialOrder.find_by(id: metadata.is_a?(Hash) ? metadata["material_order_id"] : metadata&.material_order_id)
    return if order.blank? || order.payment_paid?

    order.mark_paid!(stripe_payment_intent_id: payment_intent)
    clear_cart_for(order)
    link_guest_order_customer(order, customer_email || order.customer_email)
  end

  def finalize_quotation_deposit(session_id, payment_intent, metadata)
    payment = QuotationPayment.find_by(stripe_checkout_session_id: session_id)
    payment ||= QuotationPayment.find_by(id: metadata.is_a?(Hash) ? metadata["quotation_payment_id"] : metadata&.quotation_payment_id)
    return if payment.blank? || payment.recorded?

    payment.update!(
      status: :recorded,
      stripe_payment_intent_id: payment_intent,
      stripe_checkout_session_id: session_id
    )
    payment.quotation.sync_payment_status!
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
end
