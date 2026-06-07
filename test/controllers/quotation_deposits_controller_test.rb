require "test_helper"

class QuotationDepositsControllerTest < ActionDispatch::IntegrationTest
  test "customer can pay deposit in dev mode" do
    sign_in users(:customer)
    quotation = quotations(:accepted_job)

    post deposit_checkout_quotation_path(quotation)

    assert_redirected_to quotation_path(quotation)
    quotation.reload
    assert quotation.deposit_protected?
  end
end
