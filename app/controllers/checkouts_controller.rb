class CheckoutsController < ApplicationController
  layout "landing"

  def show
    @cart = current_cart
    redirect_to cart_path, alert: "Your cart is empty." if @cart.empty?
    @cart_items = @cart.cart_items.includes(:product)
    @order = MaterialOrder.new(fulfillment_type: :delivery, customer_email: current_user&.email)
  end

  def create
    @cart = current_cart
    redirect_to cart_path, alert: "Your cart is empty." and return if @cart.empty?

    @order = Shop::BuildOrderFromCart.call(
      cart: @cart,
      params: checkout_params.merge(user: current_user)
    )

    if @order.save
      start_stripe_checkout(@order)
    else
      @cart_items = @cart.cart_items.includes(:product)
      render :show, status: :unprocessable_entity
    end
  end

  def success
    @order = MaterialOrder.find_by!(order_number: params[:order_number])
    finalize_paid_order(@order)
    @order.update!(customer: current_user) if user_signed_in? && @order.customer_id.blank?
    current_cart.cart_items.destroy_all if current_cart.present?
  end

  def cancel
    @order = MaterialOrder.find_by(order_number: params[:order_number])
  end

  private

  def checkout_params
    attrs = params.require(:material_order).permit(
      :customer_email, :fulfillment_type, :delivery_name, :delivery_phone,
      :delivery_address, :delivery_postcode, :preferred_date, :preferred_window,
      :collection_instructions, :customer_notes
    )
    attrs[:preferred_date] = Date.parse(attrs[:preferred_date]) if attrs[:preferred_date].present?
    attrs
  end

  def finalize_paid_order(order)
    return if order.payment_paid?

    if ENV["STRIPE_SECRET_KEY"].present? && params[:session_id].present?
      session = Stripe::Checkout::Session.retrieve(params[:session_id])
      order.mark_paid!(stripe_payment_intent_id: session.payment_intent) if session.payment_status == "paid"
    end
  rescue Stripe::StripeError
    nil
  end

  def start_stripe_checkout(order)
    if ENV["STRIPE_SECRET_KEY"].blank?
      order.mark_paid!(stripe_payment_intent_id: "dev-simulated")
      current_cart.cart_items.destroy_all
      redirect_to checkout_success_path(order_number: order.order_number), notice: "Order placed (dev mode)."
      return
    end

    url = Shop::StripeCheckout.call(
      order: order,
      success_url: checkout_success_url(order_number: order.order_number, session_id: "{CHECKOUT_SESSION_ID}"),
      cancel_url: checkout_cancel_url(order_number: order.order_number)
    )
    redirect_to url, allow_other_host: true
  rescue Stripe::StripeError => e
    redirect_to checkout_path, alert: "Payment could not be started: #{e.message}"
  end
end
