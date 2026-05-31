class QuotationDocument < ApplicationRecord
  DOCUMENT_TYPES = %w[quote invoice receipt contract survey other].freeze

  belongs_to :quotation

  validates :title, :document_type, presence: true
  validates :document_type, inclusion: { in: DOCUMENT_TYPES }
end
