class QuotationDepositsController < ApplicationController
  before_action :authenticate_user!
  before_action :require_customer!
  before_action :set_quotation

  layout "dashboard"

  def create
    unless @quotation.quoted_price_cents.positive? && @quotation.deposit_cents.positive?
      redirect_to quotation_path(@quotation), alert: "Deposit payment is not available for this quotation."
      return
    end

    if @quotation.deposit_protected?
      accept_quotation_after_deposit!
      redirect_to quotation_path(@quotation), notice: "Deposit already received. Your quote is accepted."
      return
    end

    @payment = @quotation.quotation_payments.create!(
      amount_cents: @quotation.deposit_cents,
      payment_method: "stripe",
      status: :pending,
      paid_on: Date.current,
      reference: "DEP-#{SecureRandom.hex(3).upcase}"
    )

    start_stripe_checkout(@payment)
  end

  def success
    @quotation = Quotation.for_customer(current_user).find(params[:id])
    finalize_payment if params[:session_id].present?
    accept_quotation_after_deposit! if @quotation.deposit_protected?
    redirect_to quotation_path(@quotation), notice: "Deposit payment received. Your quote is now accepted and protected."
  end

  def cancel
    @quotation = Quotation.for_customer(current_user).find(params[:id])
    redirect_to quotation_path(@quotation), alert: "Deposit payment was cancelled."
  end

  private

  def set_quotation
    @quotation = Quotation.for_customer(current_user).find(params[:quotation_id] || params[:id])
  end

  def require_customer!
    return if current_user.customer?

    redirect_to dashboard_path, alert: "Only customers can pay deposits."
  end

  def start_stripe_checkout(payment)
    if ENV["STRIPE_SECRET_KEY"].blank?
      payment.update!(status: :recorded, stripe_payment_intent_id: "dev-simulated")
      @quotation.sync_payment_status!
      accept_quotation_after_deposit!
      redirect_to quotation_path(@quotation), notice: "Deposit recorded and quote accepted (dev mode)."
      return
    end

    url = Quotations::StripeCheckout.call(
      quotation: @quotation,
      payment: payment,
      success_url: deposit_success_quotation_url(@quotation, session_id: "{CHECKOUT_SESSION_ID}"),
      cancel_url: deposit_cancel_quotation_url(@quotation)
    )
    redirect_to url, allow_other_host: true
  rescue Stripe::StripeError => e
    redirect_to quotation_path(@quotation), alert: "Payment could not be started: #{e.message}"
  end

  def finalize_payment
    session = Stripe::Checkout::Session.retrieve(params[:session_id])
    payment = @quotation.quotation_payments.find_by(stripe_checkout_session_id: session.id)
    return if payment.blank? || payment.recorded?

    payment.update!(
      status: :recorded,
      stripe_payment_intent_id: session.payment_intent
    )
    @quotation.sync_payment_status!
  rescue Stripe::StripeError
    nil
  end

  def accept_quotation_after_deposit!
    return if @quotation.accepted?

    @quotation.transition_to!(:accepted, actor: current_user, note: "Customer accepted the quote after deposit payment")
    ::ActivityNotifier.call(
      recipients: User.operators,
      event_type: "quotation.customer_activity",
      title: "Quote accepted",
      body: "#{current_user.email} accepted #{@quotation.reference} after paying the deposit.",
      url: admin_quotation_path(@quotation),
      actor: current_user,
      notifiable: @quotation
    )
  end
end
