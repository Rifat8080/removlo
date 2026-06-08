require "test_helper"

class WebPushSubscriptionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @previous_public_key = ENV["VAPID_PUBLIC_KEY"]
    @previous_private_key = ENV["VAPID_PRIVATE_KEY"]
    ENV["VAPID_PUBLIC_KEY"] = "test-public-key"
    ENV["VAPID_PRIVATE_KEY"] = "test-private-key"
  end

  teardown do
    ENV["VAPID_PUBLIC_KEY"] = @previous_public_key
    ENV["VAPID_PRIVATE_KEY"] = @previous_private_key
  end

  test "signed in user can sync web push subscription" do
    sign_in users(:customer)

    assert_difference "WebPushSubscription.count", 1 do
      post web_push_subscription_path, params: subscription_payload, as: :json
    end

    assert_response :success
    subscription = WebPushSubscription.last
    assert_equal users(:customer), subscription.user
    assert_equal "https://push.example/subscription/1", subscription.endpoint
    assert_equal "p256dh-key", subscription.p256dh_key
    assert_equal "auth-key", subscription.auth_key
  end

  test "subscription endpoint is reassigned to current user when browser account changes" do
    existing = users(:customer).web_push_subscriptions.create!(
      endpoint: "https://push.example/subscription/1",
      p256dh_key: "old-key",
      auth_key: "old-auth"
    )
    sign_in users(:driver_a)

    assert_no_difference "WebPushSubscription.count" do
      post web_push_subscription_path, params: subscription_payload, as: :json
    end

    assert_response :success
    existing.reload
    assert_equal users(:driver_a), existing.user
    assert_equal "p256dh-key", existing.p256dh_key
  end

  test "destroy removes only current users subscription" do
    subscription = users(:customer).web_push_subscriptions.create!(
      endpoint: "https://push.example/subscription/1",
      p256dh_key: "p256dh-key",
      auth_key: "auth-key"
    )
    sign_in users(:customer)

    assert_difference "WebPushSubscription.count", -1 do
      delete web_push_subscription_path, params: { endpoint: subscription.endpoint }, as: :json
    end

    assert_response :success
  end

  test "json is required for subscription writes" do
    sign_in users(:customer)

    post web_push_subscription_path, params: subscription_payload

    assert_response :not_acceptable
  end

  private

  def subscription_payload
    {
      subscription: {
        endpoint: "https://push.example/subscription/1",
        keys: {
          p256dh: "p256dh-key",
          auth: "auth-key"
        }
      }
    }
  end
end
