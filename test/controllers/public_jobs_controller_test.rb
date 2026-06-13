require "test_helper"

class PublicJobsControllerTest < ActionDispatch::IntegrationTest
  test "anonymous visitor can view full shared job details" do
    quotation = quotations(:marketplace_job)

    get public_job_path(quotation.public_share_token)

    assert_response :success
    assert_match quotation.pickup_address, response.body
    assert_match quotation.delivery_address, response.body
    assert_match "Sign up as a driver", response.body
  end

  test "closed job share link returns gone page" do
    quotation = quotations(:accepted_job)
    quotation.update!(awaiting_driver_offers: false)

    get public_job_path(quotation.public_share_token)

    assert_response :gone
    assert_match "no longer open", response.body
  end

  test "signed in driver can update bid from shared job page" do
    quotation = quotations(:marketplace_job)
    offer = driver_offers(:offer_b)
    sign_in users(:driver_b)

    patch driver_job_offer_path(quotation, offer), params: { driver_offer: { amount: "480.00" } }

    assert_redirected_to driver_job_path(quotation)
    assert_equal 48_000, offer.reload.amount_cents
  end
end
