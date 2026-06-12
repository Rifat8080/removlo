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

  test "staff can send quotation through workflow without editing" do
    sign_in users(:staff)
    quotation = quotations(:accepted_job)
    quotation.update!(status: "requested")

    patch transition_admin_quotation_path(quotation), params: { status: "quoted", note: "Sent by staff" }

    assert_redirected_to admin_quotation_path(quotation)
    assert_equal "quoted", quotation.reload.status
  end

  test "staff can create quotation" do
    sign_in users(:staff)

    assert_difference "Quotation.count", 1 do
      post admin_quotations_path, params: {
        quotation: {
          customer_id: users(:customer).id,
          move_size: "studio",
          service_level: "standard",
          pickup_postcode: "M1",
          delivery_postcode: "B1",
          pickup_address: "1 Staff Street",
          delivery_address: "2 Staff Road"
        }
      }
    end

    assert_redirected_to admin_quotation_path(Quotation.order(:created_at).last)
  end

  test "staff cannot access quotation edit page" do
    sign_in users(:staff)
    quotation = quotations(:marketplace_job)

    get edit_admin_quotation_path(quotation)

    assert_redirected_to admin_quotation_path(quotation)
  end

  test "staff cannot update quotation details" do
    sign_in users(:staff)
    quotation = quotations(:marketplace_job)
    original_pickup_address = quotation.pickup_address

    patch admin_quotation_path(quotation), params: {
      quotation: {
        pickup_address: "Updated by staff"
      }
    }

    assert_redirected_to admin_quotation_path(quotation)
    assert_equal original_pickup_address, quotation.reload.pickup_address
  end

  test "staff cannot update hidden margin pricing" do
    sign_in users(:staff)
    quotation = quotations(:marketplace_job)
    original_markup = quotation.markup_percentage
    original_price = quotation.quoted_price_cents

    patch admin_quotation_path(quotation), params: {
      quotation: {
        markup_percentage: "40"
      }
    }

    assert_redirected_to admin_quotation_path(quotation)
    quotation.reload
    assert_equal original_markup, quotation.markup_percentage
    assert_equal original_price, quotation.quoted_price_cents
  end

  test "staff can propose negotiated price while quote is negotiating" do
    sign_in users(:staff)
    quotation = quotations(:marketplace_job)
    quotation.update!(status: "negotiating")

    assert_difference -> { Notification.where(event_type: "quotation.negotiated_price_pending", user: users(:admin)).count }, 1 do
      patch admin_quotation_path(quotation), params: {
        quotation: {
          negotiated_price: "725.00"
        }
      }
    end

    assert_redirected_to admin_quotation_path(quotation)
    quotation.reload
    assert_equal 72_500, quotation.pending_quoted_price_cents
    assert_equal "pending", quotation.negotiated_price_approval_status
    assert_equal users(:staff), quotation.negotiated_price_requested_by
    assert_equal 65_000, quotation.quoted_price_cents
  end

  test "staff cannot send negotiating quote before negotiated price approval" do
    sign_in users(:staff)
    quotation = quotations(:marketplace_job)
    quotation.update!(
      status: "negotiating",
      pending_quoted_price_cents: 72_500,
      negotiated_price_approval_status: "pending",
      negotiated_price_requested_by: users(:staff),
      negotiated_price_requested_at: Time.current
    )

    patch transition_admin_quotation_path(quotation), params: { status: "quoted" }

    assert_redirected_to admin_quotation_path(quotation)
    assert_equal "negotiating", quotation.reload.status
  end

  test "admin approves negotiated price and staff can send quote" do
    quotation = quotations(:marketplace_job)
    quotation.update!(
      status: "negotiating",
      pending_quoted_price_cents: 72_500,
      negotiated_price_approval_status: "pending",
      negotiated_price_requested_by: users(:staff),
      negotiated_price_requested_at: Time.current
    )

    sign_in users(:admin)
    assert_difference -> { Notification.where(event_type: "quotation.negotiated_price_approved", user: users(:staff)).count }, 1 do
      assert_difference -> { Notification.where(event_type: "quotation.negotiation_accepted", user: users(:customer)).count }, 1 do
      assert_difference -> { Notification.where(event_type: "driver_offer.negotiation_requested").count }, quotation.driver_offers.active.count do
      patch approve_negotiated_price_admin_quotation_path(quotation)
      end
      end
    end

    assert_redirected_to admin_quotation_path(quotation)
    quotation.reload
    assert_equal "approved", quotation.negotiated_price_approval_status
    assert_equal 72_500, quotation.quoted_price_cents
    assert_equal 22_500, quotation.admin_margin_cents
    assert quotation.awaiting_driver_offers?
    assert_equal "pending", driver_offers(:offer_a).reload.renegotiation_status
    assert_equal 72_500, driver_offers(:offer_a).renegotiation_price_cents

    sign_in users(:staff)
    patch transition_admin_quotation_path(quotation), params: { status: "quoted" }

    assert_redirected_to admin_quotation_path(quotation)
    assert_equal "quoted", quotation.reload.status
  end

  test "admin can reject negotiated price and notify customer" do
    quotation = quotations(:marketplace_job)
    quotation.update!(
      status: "negotiating",
      pending_quoted_price_cents: 72_500,
      negotiated_price_approval_status: "pending",
      negotiated_price_requested_by: users(:staff),
      negotiated_price_requested_at: Time.current
    )

    sign_in users(:admin)
    assert_difference -> { Notification.where(event_type: "quotation.negotiated_price_rejected", user: users(:staff)).count }, 1 do
      assert_difference -> { Notification.where(event_type: "quotation.negotiation_rejected", user: users(:customer)).count }, 1 do
        patch reject_negotiated_price_admin_quotation_path(quotation)
      end
    end

    assert_redirected_to admin_quotation_path(quotation)
    quotation.reload
    assert_equal "rejected", quotation.negotiated_price_approval_status
    assert_equal 65_000, quotation.quoted_price_cents
  end

  test "operator cannot select bid awaiting negotiated price acceptance" do
    sign_in users(:staff)
    quotation = quotations(:marketplace_job)
    offer = driver_offers(:offer_a)
    offer.update!(renegotiation_status: "pending", renegotiation_price_cents: 72_500, renegotiation_requested_at: Time.current)

    patch select_admin_quotation_driver_offer_path(quotation, offer)

    assert_redirected_to admin_quotation_path(quotation)
    assert_nil quotation.reload.selected_driver_offer
  end

  test "staff selecting driver offer cannot override hidden markup" do
    sign_in users(:staff)
    quotation = quotations(:marketplace_job)
    offer = driver_offers(:offer_a)

    patch select_admin_quotation_driver_offer_path(quotation, offer), params: { markup_percentage: "100" }

    assert_redirected_to admin_quotation_path(quotation)
    quotation.reload
    assert_equal BigDecimal("30"), quotation.markup_percentage
    assert_equal 71_500, quotation.quoted_price_cents
  end

  test "staff quotation show hides admin edit controls but shows workflow" do
    sign_in users(:staff)

    get admin_quotation_path(quotations(:marketplace_job))

    assert_response :success
    assert_no_match "Edit", response.body
    assert_no_match "Hidden Margin System", response.body
    assert_match "Bid Comparison", response.body
    assert_match "Workflow actions", response.body
  end

  test "accepted job must be deposit protected and assigned before scheduling" do
    sign_in users(:admin)
    quotation = quotations(:accepted_job)

    patch transition_admin_quotation_path(quotation), params: { status: "scheduled" }

    assert_redirected_to admin_quotation_path(quotation)
    assert_equal "accepted", quotation.reload.status
  end
end
