class MaterialOrderItem < ApplicationRecord
  belongs_to :material_order
  belongs_to :product, optional: true

  validates :product_name, :product_sku, presence: true
  validates :quantity, :unit_price_cents, :line_total_cents, numericality: { greater_than: 0 }

  before_validation :calculate_line_total

  private

  def calculate_line_total
    self.line_total_cents = quantity.to_i * unit_price_cents.to_i
  end
end
