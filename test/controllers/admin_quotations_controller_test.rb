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
