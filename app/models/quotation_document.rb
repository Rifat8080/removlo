class QuotationDocument < ApplicationRecord
  DOCUMENT_TYPES = %w[quote invoice receipt contract survey other].freeze

  belongs_to :quotation

  validates :title, :document_type, presence: true
  validates :document_type, inclusion: { in: DOCUMENT_TYPES }
  validate :url_must_be_safe_http_url

  private

  def url_must_be_safe_http_url
    return if url.blank?

    parsed_url = URI.parse(url)
    return if parsed_url.is_a?(URI::HTTP) && parsed_url.host.present?

    errors.add(:url, "must be a valid HTTP or HTTPS URL")
  rescue URI::InvalidURIError
    errors.add(:url, "must be a valid HTTP or HTTPS URL")
  end
end
