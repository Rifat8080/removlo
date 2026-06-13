require "test_helper"

class DriverJobsControllerTest < ActionDispatch::IntegrationTest
  test "driver job show does not expose customer email" do
    sign_in users(:driver_a)
    get driver_job_path(quotations(:marketplace_job))

    assert_response :success
    assert_no_match users(:customer).email, response.body
    assert_no_match quotations(:marketplace_job).pickup_address, response.body
    assert_no_match "Vehicle required", response.body
  end

  test "driver cannot see other driver offers" do
    sign_in users(:driver_a)
    get driver_job_path(quotations(:marketplace_job))

    assert_response :success
    assert_no_match "575", response.body
    assert_no_match users(:driver_b).email, response.body
  end

  test "driver can see quotation item list" do
    quotation = quotations(:marketplace_job)
    quotation.quotation_items.create!(name: "Wardrobe", quantity: 2, fragile: false, notes: "Needs dismantling")

    sign_in users(:driver_a)
    get driver_job_path(quotation)

    assert_response :success
    assert_match "Item list", response.body
    assert_match "Wardrobe", response.body
    assert_match "Needs dismantling", response.body
  end

  test "driver can accept negotiated price and update bid" do
    quotation = quotations(:marketplace_job)
    offer = driver_offers(:offer_a)
    offer.update!(
      renegotiation_price_cents: 72_500,
      renegotiation_status: "pending",
      renegotiation_requested_at: Time.current
    )

    sign_in users(:driver_a)
    get driver_job_path(quotation)

    assert_response :success
    assert_match "Negotiated price request", response.body
    assert_match "Accept negotiated price", response.body

    assert_difference -> { Notification.where(event_type: "driver_offer.negotiation_accepted").count }, User.operators.count do
      patch accept_negotiation_driver_job_offer_path(quotation, offer)
    end

    assert_redirected_to driver_job_path(quotation)
    offer.reload
    assert_equal 72_500, offer.amount_cents
    assert_equal "accepted", offer.renegotiation_status
  end

  test "new driver bid during active negotiation gets acceptance request automatically" do
    quotation = quotations(:marketplace_job)
    quotation.update!(
      status: "negotiating",
      pending_quoted_price_cents: 72_500,
      negotiated_price_approval_status: "approved",
      quoted_price_cents: 72_500,
      awaiting_driver_offers: true,
      selected_driver_offer: nil
    )
    driver_offers(:offer_b).destroy!

    sign_in users(:driver_b)
    post driver_job_offers_path(quotation), params: { driver_offer: { amount: "560.00" } }

    assert_redirected_to driver_job_path(quotation)
    assert_match "Accept the negotiated price", flash[:notice]
    offer = quotation.driver_offers.find_by!(driver: users(:driver_b))
    assert_equal 56_000, offer.amount_cents
    assert_equal "pending", offer.renegotiation_status
    assert_equal 72_500, offer.renegotiation_price_cents
  end

  test "bidding continues while other drivers already accepted negotiated price" do
    quotation = quotations(:marketplace_job)
    quotation.update!(
      status: "negotiating",
      pending_quoted_price_cents: 72_500,
      negotiated_price_approval_status: "approved",
      quoted_price_cents: 72_500,
      awaiting_driver_offers: true,
      selected_driver_offer: nil
    )
    driver_offers(:offer_a).update!(
      renegotiation_status: "pending",
      renegotiation_price_cents: 72_500,
      renegotiation_requested_at: Time.current
    )
    driver_offers(:offer_a).accept_renegotiation!
    driver_offers(:offer_b).destroy!

    sign_in users(:driver_b)
    post driver_job_offers_path(quotation), params: { driver_offer: { amount: "560.00" } }

    assert_redirected_to driver_job_path(quotation)
    offer = quotation.driver_offers.find_by!(driver: users(:driver_b))
    assert_equal "pending", offer.renegotiation_status
    assert_equal 72_500, offer.renegotiation_price_cents
    assert_equal "accepted", driver_offers(:offer_a).reload.renegotiation_status
  end
end
