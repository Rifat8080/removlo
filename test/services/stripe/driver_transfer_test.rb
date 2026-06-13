require "test_helper"

class Stripe::DriverTransferTest < ActiveSupport::TestCase
  test "successful transfer marks withdrawal request withdrawn and stores transfer id" do
    driver = users(:driver_a)
    enable_driver_stripe_payouts!(driver)
    entry = driver.driver_wallet_entries.create!(
      entry_type: :withdrawal_request,
      status: :available,
      amount_cents: -75_00,
      reference: "WITHDRAW-TRANSFER"
    )
    transfer = OpenStruct.new(id: "tr_test_success", status: "paid")

    Stripe::Balance.stub(:retrieve, stripe_balance(100_00)) do
      Stripe::Transfer.stub(:create, transfer) do
        result = Stripe::DriverTransfer.call(entry: entry, actor: users(:admin))
        assert_equal entry, result
      end
    end

    entry.reload
    assert_equal "withdrawn", entry.status
    assert_equal "tr_test_success", entry.stripe_transfer_id
    assert_equal "paid", entry.stripe_transfer_status
    assert_nil entry.stripe_transfer_error
  end

  test "stripe error does not mark withdrawal request as withdrawn" do
    driver = users(:driver_a)
    enable_driver_stripe_payouts!(driver)
    entry = driver.driver_wallet_entries.create!(
      entry_type: :withdrawal_request,
      status: :available,
      amount_cents: -75_00,
      reference: "WITHDRAW-FAIL"
    )

    Stripe::Balance.stub(:retrieve, stripe_balance(100_00)) do
      Stripe::Transfer.stub(:create, ->(*) { raise Stripe::InvalidRequestError.new("insufficient funds", nil) }) do
        assert_raises Stripe::DriverTransfer::Error do
          Stripe::DriverTransfer.call(entry: entry, actor: users(:admin))
        end
      end
    end

    entry.reload
    assert_equal "available", entry.status
    assert_equal "failed", entry.stripe_transfer_status
    assert_includes entry.stripe_transfer_error, "insufficient funds"
  end

  test "insufficient platform balance leaves request available before creating transfer" do
    driver = users(:driver_a)
    enable_driver_stripe_payouts!(driver)
    entry = driver.driver_wallet_entries.create!(
      entry_type: :withdrawal_request,
      status: :available,
      amount_cents: -75_00,
      reference: "WITHDRAW-BALANCE"
    )

    Stripe::Balance.stub(:retrieve, stripe_balance(5_10)) do
      assert_raises Stripe::DriverTransfer::Error do
        Stripe::DriverTransfer.call(entry: entry, actor: users(:admin))
      end
    end

    entry.reload
    assert_equal "available", entry.status
    assert_equal "failed", entry.stripe_transfer_status
    assert_includes entry.stripe_transfer_error, "Stripe available balance is £5.10"
    assert_includes entry.stripe_transfer_error, "needs £75.00"
  end

  private

  def enable_driver_stripe_payouts!(driver)
    driver.driver_profile.update!(
      stripe_account_id: "acct_test_driver",
      stripe_onboarding_status: "complete",
      stripe_charges_enabled: true,
      stripe_payouts_enabled: true
    )
  end

  def stripe_balance(available_cents)
    OpenStruct.new(available: [OpenStruct.new(currency: "gbp", amount: available_cents)])
  end
end
