class CartItem < ApplicationRecord
  belongs_to :cart
  belongs_to :product

  validates :quantity, numericality: { only_integer: true, greater_than: 0 }
  validates :product_id, uniqueness: { scope: :cart_id }
  validate :product_must_be_available

  before_validation :snapshot_unit_price

  def line_total_cents
    quantity.to_i * unit_price_cents.to_i
  end

  private

  def snapshot_unit_price
    self.unit_price_cents = product.price_cents if product.present?
  end

  def product_must_be_available
    return if product.blank?

    errors.add(:product, "is not available") unless product.active? && product.in_stock?
    errors.add(:quantity, "exceeds available stock") if quantity.to_i > product.stock_quantity
  end
end
