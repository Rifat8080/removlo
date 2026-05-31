class Cart < ApplicationRecord
  belongs_to :user, optional: true
  has_many :cart_items, dependent: :destroy
  has_many :material_orders, dependent: :nullify
  has_many :products, through: :cart_items

  def subtotal_cents
    cart_items.includes(:product).sum { |item| item.line_total_cents }
  end

  def item_count
    cart_items.sum(:quantity)
  end

  def empty?
    cart_items.none?
  end
end
