require "test_helper"

class Driver::WalletsControllerTest < ActionDispatch::IntegrationTest
  test "driver can request withdrawal above minimum within available balance" do
    driver = users(:driver_a)
    enable_driver_stripe_payouts!(driver)
    sign_in driver
    driver.driver_wallet_entries.create!(
      entry_type: :job_earning,
      status: :available,
      amount_cents: 100_00,
      reference: "JOB-AVAILABLE"
    )

    assert_difference -> { DriverWalletEntry.withdrawal_request.count }, 1 do
      post withdraw_driver_wallet_path, params: { withdrawal: { amount: "75.00" } }
    end

    assert_redirected_to driver_wallet_path
    request = DriverWalletEntry.withdrawal_request.order(:created_at).last
    assert_equal driver, request.driver
    assert_equal "pending", request.status
    assert_equal(-75_00, request.amount_cents)
    assert_equal "stripe", request.payout_method
    assert_equal 25_00, driver.wallet_available_cents
  end

  test "driver can request cash withdrawal without stripe onboarding" do
    driver = users(:driver_a)
    sign_in driver
    driver.driver_wallet_entries.create!(
      entry_type: :job_earning,
      status: :available,
      amount_cents: 100_00,
      reference: "JOB-CASH"
    )

    assert_difference -> { DriverWalletEntry.withdrawal_request.count }, 1 do
      post withdraw_driver_wallet_path, params: { withdrawal: { amount: "50.00", payout_method: "cash" } }
    end

    request = DriverWalletEntry.withdrawal_request.order(:created_at).last
    assert_equal "cash", request.payout_method
    assert_equal(-50_00, request.amount_cents)
    assert_equal 50_00, driver.wallet_available_cents
  end

  test "driver cannot request withdrawal below fifty pounds" do
    driver = users(:driver_a)
    enable_driver_stripe_payouts!(driver)
    sign_in driver
    driver.driver_wallet_entries.create!(
      entry_type: :job_earning,
      status: :available,
      amount_cents: 100_00,
      reference: "JOB-AVAILABLE"
    )

    assert_no_difference -> { DriverWalletEntry.withdrawal_request.count } do
      post withdraw_driver_wallet_path, params: { withdrawal: { amount: "49.99" } }
    end

    assert_redirected_to driver_wallet_path
  end

  test "driver cannot request more than available balance" do
    driver = users(:driver_a)
    enable_driver_stripe_payouts!(driver)
    sign_in driver
    driver.driver_wallet_entries.create!(
      entry_type: :job_earning,
      status: :available,
      amount_cents: 60_00,
      reference: "JOB-AVAILABLE"
    )

    assert_no_difference -> { DriverWalletEntry.withdrawal_request.count } do
      post withdraw_driver_wallet_path, params: { withdrawal: { amount: "60.01" } }
    end

    assert_redirected_to driver_wallet_path
    assert_equal 60_00, driver.wallet_available_cents
  end

  test "driver cannot withdraw before stripe payouts are enabled" do
    driver = users(:driver_a)
    sign_in driver
    driver.driver_wallet_entries.create!(
      entry_type: :job_earning,
      status: :available,
      amount_cents: 100_00,
      reference: "JOB-AVAILABLE"
    )

    assert_no_difference -> { DriverWalletEntry.withdrawal_request.count } do
      post withdraw_driver_wallet_path, params: { withdrawal: { amount: "75.00", payout_method: "stripe" } }
    end

    assert_redirected_to driver_wallet_path
    assert_match(/Stripe payout setup/i, flash[:alert].to_s)
  end

  test "cash and stripe withdrawal requests cannot exceed available earnings together" do
    driver = users(:driver_a)
    enable_driver_stripe_payouts!(driver)
    sign_in driver
    driver.driver_wallet_entries.create!(
      entry_type: :job_earning,
      status: :available,
      amount_cents: 80_00,
      reference: "JOB-COMBINED"
    )

    post withdraw_driver_wallet_path, params: { withdrawal: { amount: "50.00", payout_method: "cash" } }

    assert_no_difference -> { DriverWalletEntry.withdrawal_request.count } do
      post withdraw_driver_wallet_path, params: { withdrawal: { amount: "31.00", payout_method: "stripe" } }
    end

    assert_redirected_to driver_wallet_path
    assert_equal 30_00, driver.wallet_available_cents
  end

  test "connect stripe button bypasses turbo for external onboarding redirect" do
    sign_in users(:driver_a)

    get driver_wallet_path

    assert_response :success
    assert_match "Connect Stripe", response.body
    assert_match 'data-turbo="false"', response.body
    assert_match connect_stripe_driver_wallet_path, response.body
  end

  test "driver can start stripe connect onboarding" do
    driver = users(:driver_a)
    sign_in driver
    stripe_key = ENV["STRIPE_SECRET_KEY"]
    ENV["STRIPE_SECRET_KEY"] = "sk_test_connect"

    account = OpenStruct.new(id: "acct_test_new")
    account_link = OpenStruct.new(url: "https://connect.stripe.com/setup/test")

    Stripe::Account.stub(:create, account) do
      Stripe::AccountLink.stub(:create, account_link) do
        post connect_stripe_driver_wallet_path
      end
    end

    assert_redirected_to "https://connect.stripe.com/setup/test"
    profile = driver.driver_profile.reload
    assert_equal "acct_test_new", profile.stripe_account_id
    assert_equal "pending", profile.stripe_onboarding_status
  ensure
    stripe_key ? ENV["STRIPE_SECRET_KEY"] = stripe_key : ENV.delete("STRIPE_SECRET_KEY")
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
end
