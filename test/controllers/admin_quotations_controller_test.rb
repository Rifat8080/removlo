require "test_helper"

class AdminQuotationsControllerTest < ActionDispatch::IntegrationTest
  test "admin sees driver bids and margin" do
    sign_in users(:admin)
    get admin_quotation_path(quotations(:marketplace_job))

    assert_response :success
    assert_match "Bid Comparison", response.body
    assert_match users(:driver_a).email, response.body
    assert_match "Hidden Margin System", response.body
  end
end
