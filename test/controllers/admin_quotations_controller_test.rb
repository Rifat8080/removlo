require "test_helper"

class AdminQuotationsControllerTest < ActionDispatch::IntegrationTest
  test "admin sees driver bids and margin" do
    sign_in users(:admin)
    get admin_quotation_path(quotations(:marketplace_job))

    assert_response :success
    assert_match "Bid Comparison", response.body
    assert_match users(:driver_a).email, response.body
    assert_match "Hidden Margin System", response.body
  end

  test "admin sees outside group share link for open jobs" do
    sign_in users(:admin)
    quotation = quotations(:marketplace_job)

    get admin_quotation_path(quotation)

    assert_response :success
    assert_match "Share outside group", response.body
    assert_match public_job_path(quotation.public_share_token), response.body
  end

  test "creating quotation posts job and alerts drivers" do
    sign_in users(:admin)

    assert_difference "Quotation.count", 1 do
      assert_difference -> { Notification.where(event_type: "quotation.driver_job_alert").count }, User.drivers.count do
        post admin_quotations_path, params: {
          quotation: {
            customer_id: users(:customer).id,
            move_size: "studio",
            service_level: "standard",
            pickup_postcode: "M1",
            delivery_postcode: "B1",
            pickup_address: "1 Test Street",
            delivery_address: "2 Test Road"
          }
        }
      end
    end

    quotation = Quotation.order(:created_at).last
    assert quotation.awaiting_driver_offers?
    assert_not_nil quotation.public_share_token
  end

  test "admin selecting offer before deposit does not assign driver" do
    sign_in users(:admin)
    quotation = quotations(:marketplace_job)
    offer = driver_offers(:offer_a)

    patch select_admin_quotation_driver_offer_path(quotation, offer)

    assert_redirected_to admin_quotation_path(quotation)
    quotation.reload
    assert_equal offer, quotation.selected_driver_offer
    assert_nil quotation.assigned_driver
    assert_equal offer.amount_cents, quotation.driver_cost_cents
  end

  test "admin can unselect a selected driver offer" do
    sign_in users(:admin)
    quotation = quotations(:marketplace_job)
    selected_offer = driver_offers(:offer_a)
    other_offer = driver_offers(:offer_b)

    patch select_admin_quotation_driver_offer_path(quotation, selected_offer)
    patch select_admin_quotation_driver_offer_path(quotation, selected_offer)

    assert_redirected_to admin_quotation_path(quotation)
    quotation.reload
    assert_nil quotation.selected_driver_offer
    assert quotation.awaiting_driver_offers?
    assert selected_offer.reload.submitted?
    assert other_offer.reload.submitted?
  end

  test "admin can update markup percentage from quotation show pricing" do
    sign_in users(:admin)
    quotation = quotations(:marketplace_job)

    patch admin_quotation_path(quotation), params: {
      quotation: {
        markup_percentage: "40"
      }
    }

    assert_redirected_to admin_quotation_path(quotation)
    quotation.reload
    assert_equal BigDecimal("40"), quotation.markup_percentage
    assert_equal 70_000, quotation.quoted_price_cents
    assert_equal 20_000, quotation.admin_margin_cents
  end

  test "admin workflow only shows valid next job actions" do
    sign_in users(:admin)

    get admin_quotation_path(quotations(:marketplace_job))

    assert_response :success
    assert_match "Accept quote", response.body
    assert_no_match "Complete job", response.body
  end

  test "accepted job must be deposit protected and assigned before scheduling" do
    sign_in users(:admin)
    quotation = quotations(:accepted_job)

    patch transition_admin_quotation_path(quotation), params: { status: "scheduled" }

    assert_redirected_to admin_quotation_path(quotation)
    assert_equal "accepted", quotation.reload.status
  end
end
