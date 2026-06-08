require "test_helper"

class QuotationsControllerTest < ActionDispatch::IntegrationTest
  test "customer quotation request posts job and alerts drivers" do
    sign_in users(:customer)

    assert_difference "Quotation.count", 1 do
      assert_difference -> { Notification.where(event_type: "quotation.driver_job_alert").count }, User.drivers.count do
        post quotations_path, params: {
          quotation: {
            move_size: "studio",
            service_level: "standard",
            pickup_postcode: "M4",
            delivery_postcode: "B4",
            pickup_address: "10 New Pickup Street",
            delivery_address: "20 New Delivery Road"
          }
        }
      end
    end

    quotation = Quotation.order(:created_at).last
    assert quotation.awaiting_driver_offers?
    assert_equal "requested", quotation.status
  end

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
