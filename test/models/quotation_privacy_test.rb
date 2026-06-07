require "test_helper"

class QuotationPrivacyTest < ActiveSupport::TestCase
  test "driver cannot see exact addresses before payment release" do
    quotation = quotations(:accepted_job)

    assert_includes quotation.driver_visible_pickup_address, "M2"
    assert_not_equal quotation.pickup_address, quotation.driver_visible_pickup_address
  end

  test "driver sees exact addresses after deposit paid" do
    quotation = quotations(:accepted_job)
    quotation.update!(payment_status: :deposit_paid)

    assert_equal quotation.pickup_address, quotation.driver_visible_pickup_address
    assert_equal quotation.delivery_address, quotation.driver_visible_delivery_address
  end

  test "driver assignment blocked before deposit" do
    quotation = quotations(:accepted_job)
    quotation.assigned_driver = users(:driver_a)

    assert_not quotation.valid?
    assert_includes quotation.errors[:assigned_driver], "can only be assigned after deposit or full payment is received"
  end

  test "driver assignment allowed after deposit" do
    quotation = quotations(:accepted_job)
    quotation.update!(payment_status: :deposit_paid, assigned_driver: users(:driver_a))

    assert quotation.valid?
  end

  test "markup hides driver cost from customer price" do
    quotation = quotations(:marketplace_job)

    assert_equal 65_000, quotation.quoted_price_cents
    assert_equal 50_000, quotation.driver_cost_cents
    assert_equal 15_000, quotation.admin_margin_cents
  end
end
