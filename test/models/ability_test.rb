require "test_helper"

class AbilityTest < ActiveSupport::TestCase
  test "admin can manage everything except destroying their own user" do
    admin = users(:admin)
    ability = Ability.new(admin)

    assert ability.can?(:manage, Quotation)
    assert ability.cannot?(:destroy, admin)
  end

  test "staff cannot read another users self-service billing records" do
    staff = users(:staff)
    ability = Ability.new(staff)

    assert ability.can?(:read, Payslip.new(employee: staff))
    assert ability.cannot?(:read, CustomerInvoice.new(customer: users(:customer)))
    assert ability.cannot?(:read, MaterialOrder.new(customer: users(:customer)))
  end

  test "customer can manage only their own portal records" do
    customer = users(:customer)
    ability = Ability.new(customer)

    assert ability.can?(:read, Quotation.new(customer: customer))
    assert ability.can?(:read, CustomerInvoice.new(customer: customer))
    assert ability.cannot?(:read, Quotation.new(customer: users(:driver_a)))
  end

  test "driver can mutate assigned jobs only" do
    driver = users(:driver_a)
    ability = Ability.new(driver)

    assert ability.can?(:start, Quotation.new(customer: users(:customer), assigned_driver: driver))
    assert ability.cannot?(:start, Quotation.new(customer: users(:customer), assigned_driver: users(:driver_b)))
  end
end
