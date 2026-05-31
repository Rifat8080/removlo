class QuotationNote < ApplicationRecord
  belongs_to :quotation
  belongs_to :user, optional: true

  validates :content, presence: true
end
