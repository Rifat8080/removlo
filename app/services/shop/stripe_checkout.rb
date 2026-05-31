module Shop
  class StripeCheckout
    def self.call(order:, success_url:, cancel_url:)
      new(order, success_url, cancel_url).call
    end

    def initialize(order, success_url, cancel_url)
      @order = order
      @success_url = success_url
      @cancel_url = cancel_url
    end

    def call
      session = Stripe::Checkout::Session.create(
        mode: "payment",
        customer_email: order.customer_email,
        success_url: success_url,
        cancel_url: cancel_url,
        metadata: { material_order_id: order.id, cart_id: order.cart_id },
        line_items: line_items
      )
      order.update!(stripe_checkout_session_id: session.id)
      session.url
    end

    private

    attr_reader :order, :success_url, :cancel_url

    def line_items
      items = order.material_order_items.map do |item|
        {
          price_data: {
            currency: "gbp",
            product_data: { name: item.product_name, metadata: { sku: item.product_sku } },
            unit_amount: item.unit_price_cents
          },
          quantity: item.quantity
        }
      end

      if order.delivery_fee_cents.positive?
        items << {
          price_data: {
            currency: "gbp",
            product_data: { name: "Delivery fee" },
            unit_amount: order.delivery_fee_cents
          },
          quantity: 1
        }
      end

      items
    end
  end
end
