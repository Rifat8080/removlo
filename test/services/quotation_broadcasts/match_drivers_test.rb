require "test_helper"

class QuotationBroadcastsMatchDriversTest < ActiveSupport::TestCase
  test "filters drivers by vehicle rating and availability" do
    quotation = quotations(:marketplace_job)
    quotation.update!(preferred_move_date: Date.new(2026, 7, 15))

    broadcast = QuotationBroadcast.create!(
      quotation: quotation,
      created_by: users(:admin),
      vehicle_types: ["luton_van"],
      service_areas: ["M"],
      minimum_rating: 4.5,
      require_available: true
    )

    drivers = broadcast.matching_drivers

    assert_includes drivers, users(:driver_a)
    assert_not_includes drivers, users(:driver_b)
  end
end
