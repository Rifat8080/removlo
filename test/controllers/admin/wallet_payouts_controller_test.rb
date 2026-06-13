require "test_helper"

class Admin::WalletPayoutsControllerTest < ActionDispatch::IntegrationTest
  test "admin can approve and send stripe transfer for withdrawal request" do
    sign_in users(:admin)
    driver = users(:driver_a)
    enable_driver_stripe_payouts!(driver)
    earning = driver.driver_wallet_entries.create!(
      entry_type: :job_earning,
      status: :available,
      amount_cents: 100_00,
      reference: "JOB-AVAILABLE"
    )
    request = driver.driver_wallet_entries.create!(
      entry_type: :withdrawal_request,
      status: :pending,
      amount_cents: -75_00,
      reference: "WITHDRAW-TEST"
    )

    patch approve_admin_wallet_payout_path(request)

    assert_redirected_to admin_wallet_payouts_path
    assert_equal "available", request.reload.status
    assert_equal users(:admin), request.approved_by

    transfer = OpenStruct.new(id: "tr_admin_test", status: "paid")
    Stripe::Balance.stub(:retrieve, stripe_balance(100_00)) do
      Stripe::Transfer.stub(:create, transfer) do
        assert_no_difference "DriverWalletEntry.count" do
          patch payout_admin_wallet_payout_path(request)
        end
      end
    end

    assert_redirected_to admin_wallet_payouts_path
    assert_equal "withdrawn", request.reload.status
    assert_equal "tr_admin_test", request.stripe_transfer_id
    assert_equal 25_00, driver.wallet_available_cents
    assert_equal "available", earning.reload.status
  end

  test "failed stripe transfer leaves withdrawal request available" do
    sign_in users(:admin)
    driver = users(:driver_a)
    enable_driver_stripe_payouts!(driver)
    request = driver.driver_wallet_entries.create!(
      entry_type: :withdrawal_request,
      status: :available,
      amount_cents: -75_00,
      reference: "WITHDRAW-FAIL"
    )

    Stripe::Balance.stub(:retrieve, stripe_balance(100_00)) do
      Stripe::Transfer.stub(:create, ->(*) { raise Stripe::InvalidRequestError.new("insufficient funds", nil) }) do
        patch payout_admin_wallet_payout_path(request)
      end
    end

    assert_redirected_to admin_wallet_payouts_path
    request.reload
    assert_equal "available", request.status
    assert_equal "failed", request.stripe_transfer_status
    assert_includes request.stripe_transfer_error, "insufficient funds"
  end

  test "admin can mark cash withdrawal request as paid without creating duplicate payout entry" do
    sign_in users(:admin)
    driver = users(:driver_a)
    earning = driver.driver_wallet_entries.create!(
      entry_type: :job_earning,
      status: :available,
      amount_cents: 80_00,
      reference: "JOB-CASH-AVAILABLE"
    )
    request = driver.driver_wallet_entries.create!(
      entry_type: :withdrawal_request,
      status: :pending,
      amount_cents: -50_00,
      payout_method: "cash",
      reference: "WITHDRAW-CASH"
    )

    patch approve_admin_wallet_payout_path(request)
    assert_equal "available", request.reload.status

    assert_no_difference "DriverWalletEntry.count" do
      patch payout_admin_wallet_payout_path(request)
    end

    assert_redirected_to admin_wallet_payouts_path
    assert_equal "withdrawn", request.reload.status
    assert_equal "available", earning.reload.status
    assert_equal 30_00, driver.wallet_available_cents
  end

  test "approved job earnings are not listed as direct payout options" do
    sign_in users(:admin)
    driver = users(:driver_a)
    driver.driver_wallet_entries.create!(
      entry_type: :job_earning,
      status: :available,
      amount_cents: 80_00,
      reference: "JOB-NO-DIRECT-PAYOUT"
    )

    get admin_wallet_payouts_path

    assert_response :success
    assert_no_match "JOB-NO-DIRECT-PAYOUT", response.body
  end

  test "direct payout endpoint refuses job earnings" do
    sign_in users(:admin)
    entry = users(:driver_a).driver_wallet_entries.create!(
      entry_type: :job_earning,
      status: :available,
      amount_cents: 80_00,
      reference: "JOB-BLOCKED-PAYOUT"
    )

    assert_no_difference "DriverWalletEntry.count" do
      patch payout_admin_wallet_payout_path(entry)
    end

    assert_redirected_to admin_wallet_payouts_path
    assert_equal "available", entry.reload.status
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
