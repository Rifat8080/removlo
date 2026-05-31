class QuotationItem < ApplicationRecord
  belongs_to :quotation

  validates :name, presence: true
  validates :quantity, numericality: { only_integer: true, greater_than: 0 }
end
