class CartsController < ApplicationController
  layout "landing"

  def show
    @cart = current_cart
    authorize! :read, @cart
    @cart_items = @cart.cart_items.includes(product: { image_attachment: :blob })
  end

  def add
    authorize! :manage, current_cart
    product = Product.active.find(params[:product_id])
    quantity = params.fetch(:quantity, 1).to_i.clamp(1, 99)
    add_product_to_cart(product, quantity)
    redirect_to cart_path, notice: "#{product.name} added to cart."
  rescue ActiveRecord::RecordInvalid => e
    redirect_back fallback_location: shop_product_path(product), alert: e.record.errors.full_messages.to_sentence
  end

  def update
    authorize! :manage, current_cart
    item = current_cart.cart_items.find(params[:id])
    if params[:quantity].to_i <= 0
      item.destroy
    else
      item.update!(quantity: params[:quantity])
    end
    redirect_to cart_path, notice: "Cart updated."
  rescue ActiveRecord::RecordInvalid => e
    redirect_to cart_path, alert: e.record.errors.full_messages.to_sentence
  end

  def remove
    authorize! :manage, current_cart
    current_cart.cart_items.find(params[:id]).destroy
    redirect_to cart_path, notice: "Item removed."
  end

  private

  def add_product_to_cart(product, quantity)
    item = current_cart.cart_items.find_by(product: product)
    if item
      item.increment!(:quantity, quantity)
    else
      current_cart.cart_items.create!(product: product, quantity: quantity)
    end
  rescue ActiveRecord::RecordNotUnique
    current_cart.cart_items.find_by!(product: product).increment!(:quantity, quantity)
  end
end
