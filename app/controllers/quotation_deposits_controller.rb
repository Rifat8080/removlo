class QuotationDepositsController < ApplicationController
  before_action :authenticate_user!
  before_action :require_customer!
  before_action :set_quotation

  layout "dashboard"

  def create
    if @quotation.paid?
      redirect_to quotation_path(@quotation), notice: "This quotation is already paid."
      return
    end

    unless @quotation.quoted_price_cents.positive?
      redirect_to quotation_path(@quotation), alert: "Stripe payment is not available until a quote price is set."
      return
    end

    payment_amount_cents = acceptance_payment_amount_cents
    payment_kind = @quotation.deposit_cents.positive? ? "quotation_deposit" : "quotation_acceptance"

    if @quotation.deposit_protected? && payment_kind == "quotation_deposit"
      accept_quotation_after_deposit!
      redirect_to quotation_path(@quotation), notice: "Deposit already received. Your quote is accepted."
      return
    end

    @payment = @quotation.quotation_payments.create!(
      amount_cents: payment_amount_cents,
      payment_method: "stripe",
      status: :pending,
      paid_on: Date.current,
      reference: "#{payment_kind == "quotation_deposit" ? "DEP" : "FULL"}-#{SecureRandom.hex(3).upcase}"
    )

    start_stripe_checkout(@payment, payment_kind: payment_kind)
  end

  def balance
    unless @quotation.accepted? && @quotation.remaining_balance_cents.positive?
      redirect_to quotation_path(@quotation), alert: "Balance payment is not available for this quotation."
      return
    end

    @payment = @quotation.quotation_payments.create!(
      amount_cents: @quotation.remaining_balance_cents,
      payment_method: "stripe",
      status: :pending,
      paid_on: Date.current,
      reference: "BAL-#{SecureRandom.hex(3).upcase}"
    )

    start_stripe_checkout(
      @payment,
      payment_kind: "quotation_balance",
      success_url: balance_success_quotation_url(@quotation, session_id: "{CHECKOUT_SESSION_ID}"),
      cancel_url: balance_cancel_quotation_url(@quotation, payment_id: @payment.id)
    )
  end

  def success
    @quotation = Quotation.for_customer(current_user).find(params[:id])
    payment = finalize_payment if params[:session_id].present?

    if payment&.recorded?
      accept_quotation_after_deposit! if @quotation.deposit_protected?
      redirect_to quotation_path(@quotation), notice: "Payment received. Your quote is now accepted and protected."
    elsif @quotation.reload.deposit_protected?
      redirect_to quotation_path(@quotation), notice: "Payment already received. Your quote is accepted and protected."
    else
      redirect_to quotation_path(@quotation), alert: "Stripe payment could not be verified yet. Please try again or contact support if money was taken."
    end
  end

  def cancel
    @quotation = Quotation.for_customer(current_user).find(params[:id])
    mark_payment_failed(params[:payment_id])
    redirect_to quotation_path(@quotation), alert: "Deposit payment was cancelled."
  end

  def balance_success
    @quotation = Quotation.for_customer(current_user).find(params[:id])
    payment = finalize_payment if params[:session_id].present?

    if payment&.recorded?
      redirect_to quotation_path(@quotation), notice: "Balance payment received. Thank you."
    elsif @quotation.reload.paid?
      redirect_to quotation_path(@quotation), notice: "Balance already received. Thank you."
    else
      redirect_to quotation_path(@quotation), alert: "Stripe payment could not be verified yet. Please try again or contact support if money was taken."
    end
  end

  def balance_cancel
    @quotation = Quotation.for_customer(current_user).find(params[:id])
    mark_payment_failed(params[:payment_id])
    redirect_to quotation_path(@quotation), alert: "Balance payment was cancelled."
  end

  private

  def set_quotation
    @quotation = Quotation.for_customer(current_user).find(params[:quotation_id] || params[:id])
  end

  def require_customer!
    return if current_user.customer?

    redirect_to dashboard_path, alert: "Only customers can pay deposits."
  end

  def start_stripe_checkout(payment, payment_kind: "quotation_deposit", success_url: nil, cancel_url: nil)
    if ENV["STRIPE_SECRET_KEY"].blank?
      if Rails.env.production?
        redirect_to quotation_path(@quotation), alert: "Stripe payment is not configured. Please contact support."
        return
      end

      payment.update!(status: :recorded, stripe_payment_intent_id: "dev-simulated")
      @quotation.sync_payment_status!
      accept_quotation_after_deposit! if payment_kind.in?(%w[quotation_deposit quotation_acceptance])
      notice =
        if payment_kind == "quotation_balance"
          "Balance recorded (dev mode)."
        elsif payment_kind == "quotation_acceptance"
          "Full quotation payment recorded and quote accepted (dev mode)."
        else
          "Deposit recorded and quote accepted (dev mode)."
        end
      redirect_to quotation_path(@quotation), notice: notice
      return
    end

    url = Quotations::StripeCheckout.call(
      quotation: @quotation,
      payment: payment,
      success_url: success_url || deposit_success_quotation_url(@quotation, session_id: "{CHECKOUT_SESSION_ID}"),
      cancel_url: cancel_url || deposit_cancel_quotation_url(@quotation, payment_id: payment.id),
      payment_kind: payment_kind
    )
    redirect_to url, allow_other_host: true
  rescue Stripe::StripeError => e
    redirect_to quotation_path(@quotation), alert: "Payment could not be started: #{e.message}"
  end

  def finalize_payment
    session = Stripe::Checkout::Session.retrieve(params[:session_id])
    return unless stripe_session_paid?(session)

    payment = @quotation.quotation_payments.find_by(stripe_checkout_session_id: session.id)
    payment ||= @quotation.quotation_payments.find_by(id: stripe_metadata_value(session.metadata, "quotation_payment_id"))
    return if payment.blank?
    return payment if payment.recorded?

    payment.update!(
      status: :recorded,
      stripe_payment_intent_id: session.payment_intent
    )
    Accounting::SyncQuotationPayment.call(payment)
    @quotation.sync_payment_status!
    payment
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

  def acceptance_payment_amount_cents
    return @quotation.deposit_cents if @quotation.deposit_cents.positive?

    @quotation.remaining_balance_cents
  end

  def mark_payment_failed(payment_id)
    return if payment_id.blank?

    payment = @quotation.quotation_payments.pending.find_by(id: payment_id)
    return if payment.blank?

    payment.update!(status: :failed, notes: "Stripe checkout was cancelled before completion.")
    Accounting::SyncQuotationPayment.call(payment)
  end

  def stripe_session_paid?(session)
    session.respond_to?(:payment_status) && session.payment_status == "paid"
  end

  def stripe_metadata_value(metadata, key)
    metadata.is_a?(Hash) ? metadata[key] : metadata&.public_send(key)
  end
end
