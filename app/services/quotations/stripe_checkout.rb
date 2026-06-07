module Quotations
  class StripeCheckout
    def self.call(quotation:, payment:, success_url:, cancel_url:)
      new(quotation, payment, success_url, cancel_url).call
    end

    def initialize(quotation, payment, success_url, cancel_url)
      @quotation = quotation
      @payment = payment
      @success_url = success_url
      @cancel_url = cancel_url
    end

    def call
      session = Stripe::Checkout::Session.create(
        mode: "payment",
        customer_email: quotation.customer.email,
        success_url: success_url,
        cancel_url: cancel_url,
        metadata: {
          quotation_id: quotation.id,
          quotation_payment_id: payment.id,
          payment_kind: "quotation_deposit"
        },
        line_items: [
          {
            price_data: {
              currency: "gbp",
              product_data: {
                name: "Deposit for #{quotation.reference}",
                description: "Removlo move deposit"
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

    attr_reader :quotation, :payment, :success_url, :cancel_url
  end
end
