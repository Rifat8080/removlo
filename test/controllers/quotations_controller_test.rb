require "test_helper"

class QuotationsControllerTest < ActionDispatch::IntegrationTest
  test "anonymous visitor can request quotation from public form" do
    assert_difference "User.count", 1 do
      assert_difference "Quotation.count", 1 do
        post quotations_path, params: {
          quotation: {
            customer_email: "new-mover@example.com",
            move_size: "two_bed",
            service_level: "standard",
            pickup_postcode: "SW1A 1AA",
            delivery_postcode: "M1 1AD",
            customer_notes: "Need packing help"
          }
        }
      end
    end

    assert_redirected_to quotation_path(Quotation.order(:created_at).last)
  end

  test "customer quotation request posts job and alerts drivers" do
    sign_in users(:customer)

    assert_difference "Quotation.count", 1 do
      assert_difference "QuotationItem.count", 1 do
        assert_difference -> { Notification.where(event_type: "quotation.driver_job_alert").count }, User.drivers.count do
          post quotations_path, params: {
            quotation: {
              move_size: "studio",
              service_level: "standard",
              pickup_postcode: "M4",
              delivery_postcode: "B4",
              pickup_address: "10 New Pickup Street",
              delivery_address: "20 New Delivery Road",
              quotation_items_attributes: {
                "0" => {
                  name: "Sofa",
                  quantity: 1,
                  fragile: "0",
                  notes: "Two seater"
                }
              }
            }
          }
        end
      end
    end

    quotation = Quotation.order(:created_at).last
    assert quotation.awaiting_driver_offers?
    assert_equal "requested", quotation.status
    assert_equal "Sofa", quotation.quotation_items.first.name
  end

  test "customer can edit their pending quotation request and add items" do
    sign_in users(:customer)
    quotation = quotations(:marketplace_job)

    get edit_quotation_path(quotation)
    assert_response :success

    assert_difference -> { quotation.quotation_items.reload.count }, 1 do
      patch quotation_path(quotation), params: {
        quotation: {
          move_size: "three_bed",
          service_level: "packing",
          pickup_postcode: "M10",
          delivery_postcode: "B10",
          pickup_address: "10 Updated Pickup Street",
          delivery_address: "20 Updated Delivery Road",
          customer_notes: "Please include packing",
          quotation_items_attributes: {
            "0" => {
              name: "Dining table",
              quantity: 1,
              fragile: "0",
              notes: "Needs legs removed"
            }
          }
        }
      }
    end

    assert_redirected_to quotation_path(quotation)
    quotation.reload
    assert_equal "10 Updated Pickup Street", quotation.pickup_address
    assert_equal "negotiating", quotation.status
    assert_equal "Dining table", quotation.quotation_items.order(:created_at).last.name
  end

  test "customer cannot edit a locked quotation request" do
    sign_in users(:customer)
    quotation = quotations(:accepted_job)

    get edit_quotation_path(quotation)

    assert_redirected_to quotation_path(quotation)
  end

  test "customer quotation show does not expose driver bids or margin" do
    sign_in users(:customer)
    get quotation_path(quotations(:marketplace_job))

    assert_response :success
    assert_no_match "driver_cost", response.body
    assert_no_match "50,000", response.body
    assert_no_match users(:driver_a).email, response.body
    assert_match "650", response.body
  end

  test "customer acceptance requires deposit before quote is accepted" do
    sign_in users(:customer)
    quotation = quotations(:marketplace_job)

    patch accept_quotation_path(quotation)

    assert_redirected_to quotation_path(quotation)
    assert_equal "quoted", quotation.reload.status
  end

  test "customer direct accept is blocked when deposit amount is not set" do
    sign_in users(:customer)
    quotation = quotations(:marketplace_job)
    quotation.update!(deposit_cents: 0)

    patch accept_quotation_path(quotation)

    assert_redirected_to quotation_path(quotation)
    assert_equal "quoted", quotation.reload.status

    get quotation_path(quotation)
    assert_response :success
    assert_no_match "Pay deposit to accept", response.body
    assert_match "Pay full quote to accept", response.body
  end

  test "customer quote page reconciles paid Stripe checkout when webhook was missed" do
    sign_in users(:customer)
    quotation = quotations(:marketplace_job)
    quotation.update!(status: "quoted", deposit_cents: 0)
    payment = quotation.quotation_payments.create!(
      amount_cents: quotation.quoted_price_cents,
      payment_method: "stripe",
      status: :pending,
      paid_on: Date.current,
      reference: "FULL-RECON",
      stripe_checkout_session_id: "cs_paid_reconcile"
    )
    stripe_session = Struct.new(:id, :payment_intent, :payment_status, :metadata).new(
      "cs_paid_reconcile",
      "pi_paid_reconcile",
      "paid",
      {
        "quotation_payment_id" => payment.id,
        "payment_kind" => "quotation_acceptance"
      }
    )
    stripe_key = ENV["STRIPE_SECRET_KEY"]
    ENV["STRIPE_SECRET_KEY"] = "sk_test_reconcile"

    Stripe::Checkout::Session.stub(:retrieve, stripe_session) do
      get quotation_path(quotation)
    end

    assert_response :success
    assert payment.reload.recorded?
    assert quotation.reload.accepted?
    assert quotation.paid?
  ensure
    stripe_key ? ENV["STRIPE_SECRET_KEY"] = stripe_key : ENV.delete("STRIPE_SECRET_KEY")
  end

  test "accepted quotation show hides decision buttons" do
    sign_in users(:customer)
    quotation = quotations(:accepted_job)

    get quotation_path(quotation)

    assert_response :success
    assert_no_match "Pay deposit to accept", response.body
    assert_no_match "Reject quote", response.body
    assert_match "Quote accepted", response.body
  end

  test "paid full quotation does not show pending deposit" do
    sign_in users(:customer)
    quotation = quotations(:marketplace_job)
    quotation.update!(status: "accepted", deposit_cents: 0)
    quotation.quotation_payments.create!(
      amount_cents: quotation.quoted_price_cents,
      payment_method: "stripe",
      status: :recorded,
      paid_on: Date.current,
      reference: "FULL-SHOW"
    )

    get quotation_path(quotation)

    assert_response :success
    assert_match "Paid in full", response.body
    assert_no_match "Deposit</p>\n        <p class=\"mt-2 text-2xl font-black\">Pending", response.body
  end
end
