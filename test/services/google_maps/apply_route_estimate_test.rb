require "test_helper"

class GoogleMaps::ApplyRouteEstimateTest < ActiveSupport::TestCase
  test "stores route estimate result on quotation" do
    quotation = quotations(:marketplace_job)
    result = GoogleMaps::RouteEstimator::Result.new(
      pickup_latitude: 53.48,
      pickup_longitude: -2.24,
      delivery_latitude: 52.48,
      delivery_longitude: -1.89,
      distance_meters: 120_000,
      duration_seconds: 5400,
      summary: "M6",
      polyline: "abc123"
    )

    GoogleMaps::RouteEstimator.stub(:call, result) do
      GoogleMaps::ApplyRouteEstimate.call(quotation: quotation)
    end

    quotation.reload
    assert quotation.route_estimated?
    assert_equal "M6", quotation.route_summary
    assert_nil quotation.route_estimate_error
  end

  test "records error when estimate unavailable" do
    quotation = quotations(:marketplace_job)

    GoogleMaps::RouteEstimator.stub(:call, nil) do
      GoogleMaps::Client.stub(:configured?, true) do
        GoogleMaps::ApplyRouteEstimate.call(quotation: quotation)
      end
    end

    quotation.reload
    assert_equal "Could not estimate route", quotation.route_estimate_error
  end
end
