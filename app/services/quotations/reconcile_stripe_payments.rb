module Quotations
  class ReconcileStripePayments
    ACCEPTANCE_PAYMENT_KINDS = %w[quotation_deposit quotation_acceptance].freeze

    def self.call(quotation:, actor: nil)
      new(quotation, actor: actor).call
    end

    def initialize(quotation, actor: nil)
      @quotation = quotation
      @actor = actor || quotation.customer
      @changed = false
    end

    def call
      return false if ENV["STRIPE_SECRET_KEY"].blank?

      pending_stripe_payments.each { |payment| reconcile(payment) }
      changed
    end

    private

    attr_reader :quotation, :actor, :changed

    def pending_stripe_payments
      quotation.quotation_payments.pending.where(payment_method: "stripe").where.not(stripe_checkout_session_id: [nil, ""]).order(created_at: :desc)
    end

    def reconcile(payment)
      session = Stripe::Checkout::Session.retrieve(payment.stripe_checkout_session_id)
      return unless session_paid?(session)
      return if already_satisfied?(session)

      payment.update!(
        status: :recorded,
        stripe_payment_intent_id: session.payment_intent
      )
      Accounting::SyncQuotationPayment.call(payment)
      quotation.sync_payment_status!
      accept_quotation_after_payment if acceptance_payment?(session)
      @changed = true
    rescue Stripe::StripeError
      nil
    end

    def session_paid?(session)
      session.respond_to?(:payment_status) && session.payment_status == "paid"
    end

    def acceptance_payment?(session)
      ACCEPTANCE_PAYMENT_KINDS.include?(metadata_value(session.metadata, "payment_kind"))
    end

    def already_satisfied?(session)
      payment_kind = metadata_value(session.metadata, "payment_kind")

      return quotation.deposit_protected? if payment_kind == "quotation_deposit"
      return quotation.paid? if payment_kind == "quotation_acceptance"
      return quotation.remaining_balance_cents <= 0 if payment_kind == "quotation_balance"

      false
    end

    def metadata_value(metadata, key)
      metadata.is_a?(Hash) ? metadata[key] : metadata&.public_send(key)
    end

    def accept_quotation_after_payment
      return if quotation.accepted?

      quotation.transition_to!(:accepted, actor: actor, note: "Customer accepted the quote after Stripe payment")
      ::ActivityNotifier.call(
        recipients: User.operators,
        event_type: "quotation.customer_activity",
        title: "Quote accepted",
        body: "#{quotation.customer.email} accepted #{quotation.reference} after Stripe payment.",
        url: Rails.application.routes.url_helpers.admin_quotation_path(quotation),
        actor: actor,
        notifiable: quotation
      )
    end
  end
end
