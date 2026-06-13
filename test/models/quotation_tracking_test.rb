require "test_helper"

class QuotationTrackingTest < ActiveSupport::TestCase
  test "tracking is visible for scheduled assigned jobs" do
    quotation = quotations(:booked_job)

    assert quotation.tracking_visible_to_customer?
    assert quotation.tracking_active?
  end

  test "tracking is hidden before assignment and schedule" do
    quotation = quotations(:marketplace_job)

    assert_not quotation.tracking_visible_to_customer?
  end

  test "route estimate helpers format distance and duration" do
    quotation = quotations(:marketplace_job)
    quotation.update!(
      route_distance_meters: 160_934,
      route_duration_seconds: 5400,
      route_estimated_at: Time.current
    )

    assert quotation.route_estimated?
    assert_equal 100.0, quotation.route_distance_miles
    assert_equal "1h 30m drive", quotation.route_duration_label
  end

  test "google directions url is generated from addresses" do
    quotation = quotations(:marketplace_job)

    assert_includes quotation.google_directions_url, "google.com/maps/dir"
    assert_includes quotation.google_maps_pickup_url, "google.com/maps/search"
  end

  test "google destination query does not force UK suffix" do
    quotation = quotations(:booked_job)
    quotation.update!(
      status: "in_progress",
      delivery_address: "PF7G+V42, Basher Pool-Dogair Bazar, Dhaka 1361, Bangladesh",
      delivery_postcode: "1361"
    )

    assert_includes quotation.tracking_destination_query, "Bangladesh"
    assert_not_includes quotation.tracking_destination_query, "UK"
  end
end
