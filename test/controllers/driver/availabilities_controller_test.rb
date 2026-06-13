require "test_helper"

class Driver::AvailabilitiesControllerTest < ActionDispatch::IntegrationTest
  test "driver can view availability calendar" do
    sign_in users(:driver_a)

    get driver_availabilities_path

    assert_response :success
    assert_match "Availability calendar", response.body
    assert_match "Off duty", response.body
  end

  test "driver can save availability status" do
    sign_in users(:driver_a)
    available_on = Date.current.next_month.beginning_of_month

    assert_difference "DriverAvailability.count", 1 do
      post driver_availabilities_path, params: {
        driver_availability: {
          available_on: available_on,
          status: "off_duty",
          notes: "Unavailable"
        }
      }
    end

    assert_redirected_to driver_availabilities_path(month: available_on.strftime("%Y-%m"))
    assert_equal "off_duty", DriverAvailability.order(:created_at).last.status
  end
end
