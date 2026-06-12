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
end
