require "test_helper"

class QuotationDocumentTest < ActiveSupport::TestCase
  test "accepts http and https urls" do
    quotation = quotations(:marketplace_job)

    assert quotation.quotation_documents.new(title: "Quote", document_type: "quote", url: "https://example.com/quote.pdf").valid?
    assert quotation.quotation_documents.new(title: "Quote", document_type: "quote", url: "http://example.com/quote.pdf").valid?
  end

  test "rejects unsafe document urls" do
    document = quotations(:marketplace_job).quotation_documents.new(
      title: "Unsafe",
      document_type: "quote",
      url: "javascript:alert(1)"
    )

    assert_not document.valid?
    assert_includes document.errors[:url], "must be a valid HTTP or HTTPS URL"
  end
end
