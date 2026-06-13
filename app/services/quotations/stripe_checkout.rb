module Quotations
  class StripeCheckout
    def self.call(quotation:, payment:, success_url:, cancel_url:, payment_kind: "quotation_deposit")
      new(quotation, payment, success_url, cancel_url, payment_kind).call
    end

    def initialize(quotation, payment, success_url, cancel_url, payment_kind)
      @quotation = quotation
      @payment = payment
      @success_url = success_url
      @cancel_url = cancel_url
      @payment_kind = payment_kind
    end

    def call
      metadata = {
        quotation_id: quotation.id,
        quotation_payment_id: payment.id,
        payment_kind: payment_kind
      }

      session = Stripe::Checkout::Session.create(
        mode: "payment",
        customer_email: quotation.customer.email,
        success_url: success_url,
        cancel_url: cancel_url,
        metadata: metadata,
        payment_intent_data: {
          metadata: metadata
        },
        line_items: [
          {
            price_data: {
              currency: "gbp",
              product_data: {
                name: product_name,
                description: product_description
              },
              unit_amount: payment.amount_cents
            },
            quantity: 1
          }
        ]
      )

      payment.update!(stripe_checkout_session_id: session.id, status: :pending)
      session.url
    end

    private

    attr_reader :quotation, :payment, :success_url, :cancel_url, :payment_kind

    def product_name
      case payment_kind
      when "quotation_balance"
        "Balance for #{quotation.reference}"
      when "quotation_acceptance"
        "Full quotation payment for #{quotation.reference}"
      else
        "Deposit for #{quotation.reference}"
      end
    end

    def product_description
      case payment_kind
      when "quotation_balance"
        "Removlo quotation balance"
      when "quotation_acceptance"
        "Removlo full quotation payment"
      else
        "Removlo move deposit"
      end
    end
  end
end
