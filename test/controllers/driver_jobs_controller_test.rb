require "test_helper"

class DriverJobsControllerTest < ActionDispatch::IntegrationTest
  test "driver job show does not expose customer email" do
    sign_in users(:driver_a)
    get driver_job_path(quotations(:marketplace_job))

    assert_response :success
    assert_no_match users(:customer).email, response.body
    assert_no_match quotations(:marketplace_job).pickup_address, response.body
  end

  test "driver cannot see other driver offers" do
    sign_in users(:driver_a)
    get driver_job_path(quotations(:marketplace_job))

    assert_response :success
    assert_no_match "575", response.body
    assert_no_match users(:driver_b).email, response.body
  end
end
