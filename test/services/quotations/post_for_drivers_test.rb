require "test_helper"

class QuotationsPostForDriversTest < ActiveSupport::TestCase
  test "opens job for offers and notifies all drivers once" do
    quotation = quotations(:accepted_job)
    quotation.update!(awaiting_driver_offers: false)

    assert_difference -> { Notification.where(event_type: "quotation.driver_job_alert").count }, User.drivers.count do
      Quotations::PostForDrivers.call(quotation: quotation, actor: users(:admin))
    end

    assert quotation.reload.awaiting_driver_offers?
  end

  test "does not notify again when job is already open" do
    quotation = quotations(:marketplace_job)

    assert_no_difference -> { Notification.where(event_type: "quotation.driver_job_alert").count } do
      Quotations::PostForDrivers.call(quotation: quotation, actor: users(:admin))
    end
  end
end
