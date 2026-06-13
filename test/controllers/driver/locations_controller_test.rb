require "test_helper"

class Driver::LocationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @job = quotations(:booked_job)
    @eta_result = GoogleMaps::EtaCalculator::Result.new(eta_seconds: 600, distance_meters: 5000, destination_label: "Pickup")
  end

  test "assigned driver can share location for active job" do
    sign_in users(:driver_a)

    GoogleMaps::EtaCalculator.stub(:call, @eta_result) do
      assert_difference "DriverLocation.count", 1 do
        post driver_job_location_path(@job), params: {
          latitude: 53.4808,
          longitude: -2.2426,
          accuracy: 10
        }, as: :json
      end
    end

    assert_response :created
  end

  test "assigned driver can share location when Google ETA fails" do
    sign_in users(:driver_a)

    GoogleMaps::EtaCalculator.stub(:call, nil) do
      assert_difference "DriverLocation.count", 1 do
        post driver_job_location_path(@job), params: {
          latitude: 53.4808,
          longitude: -2.2426,
          accuracy: 10
        }, as: :json
      end
    end

    assert_response :created
    assert_nil DriverLocation.order(:created_at).last.eta_seconds
  end

  test "other drivers cannot share location" do
    sign_in users(:driver_b)

    post driver_job_location_path(@job), params: {
      latitude: 53.4808,
      longitude: -2.2426
    }, as: :json

    assert_response :forbidden
  end

  test "customer quotation page shows tracking for scheduled job" do
    sign_in users(:customer)

    get quotation_path(@job)

    assert_response :success
    assert_match "Live tracking", response.body
    assert_match "Driver live location", response.body
    assert_no_match "Recent updates", response.body
  end

  test "driver job page shows tracking controls for assigned job" do
    sign_in users(:driver_a)

    get driver_job_path(@job)

    assert_response :success
    assert_match "Start sharing", response.body
    assert_no_match "Tracking feed", response.body
  end
end
