module Shop
  class BuildOrderFromCart
    def self.call(cart:, params:)
      new(cart, params).call
    end

    def initialize(cart, params)
      @cart = cart
      @params = params
    end

    def call
      order = MaterialOrder.new(order_attributes)
      cart.cart_items.includes(:product).find_each do |item|
        order.material_order_items.build(
          product: item.product,
          product_name: item.product.name,
          product_sku: item.product.sku,
          quantity: item.quantity,
          unit_price_cents: item.unit_price_cents
        )
      end
      subtotal = order.material_order_items.sum(&:line_total_cents)
      delivery_fee = order.delivery? ? MaterialOrder::DELIVERY_FEE_CENTS : 0
      order.assign_attributes(subtotal_cents: subtotal, delivery_fee_cents: delivery_fee, total_cents: subtotal + delivery_fee)
      order
    end

    private

    attr_reader :cart, :params

    def order_attributes
      {
        cart: cart,
        customer: params[:user],
        customer_email: params[:customer_email],
        fulfillment_type: params[:fulfillment_type],
        delivery_name: params[:delivery_name],
        delivery_phone: params[:delivery_phone],
        delivery_address: params[:delivery_address],
        delivery_postcode: params[:delivery_postcode],
        preferred_date: params[:preferred_date],
        preferred_window: params[:preferred_window],
        collection_instructions: params[:collection_instructions],
        customer_notes: params[:customer_notes],
        status: :pending,
        payment_status: :unpaid
      }
    end
  end
end
