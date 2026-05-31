class QuotationStatusEvent < ApplicationRecord
  belongs_to :quotation
  belongs_to :user, optional: true

  validates :to_status, presence: true
end
