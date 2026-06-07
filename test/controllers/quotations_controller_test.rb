require "test_helper"

class QuotationsControllerTest < ActionDispatch::IntegrationTest
  test "customer quotation show does not expose driver bids or margin" do
    sign_in users(:customer)
    get quotation_path(quotations(:marketplace_job))

    assert_response :success
    assert_no_match "driver_cost", response.body
    assert_no_match "50,000", response.body
    assert_no_match users(:driver_a).email, response.body
    assert_match "650", response.body
  end
end
