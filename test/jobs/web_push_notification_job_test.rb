require "test_helper"

class WebPushNotificationJobTest < ActiveJob::TestCase
  setup do
    @previous_public_key = ENV["VAPID_PUBLIC_KEY"]
    @previous_private_key = ENV["VAPID_PRIVATE_KEY"]
    @previous_subject = ENV["VAPID_SUBJECT"]
    ENV["VAPID_PUBLIC_KEY"] = "test-public-key"
    ENV["VAPID_PRIVATE_KEY"] = "test-private-key"
    ENV["VAPID_SUBJECT"] = "mailto:test@example.com"
  end

  teardown do
    ENV["VAPID_PUBLIC_KEY"] = @previous_public_key
    ENV["VAPID_PRIVATE_KEY"] = @previous_private_key
    ENV["VAPID_SUBJECT"] = @previous_subject
  end

  test "sends rich push payload to every subscription" do
    user = users(:customer)
    user.web_push_subscriptions.create!(
      endpoint: "https://push.example/subscription/1",
      p256dh_key: "p256dh-key",
      auth_key: "auth-key"
    )
    notification = user.notifications.create!(
      event_type: "chat.message",
      title: "New message",
      body: "A coordinator replied.",
      url: "/conversations/123"
    )
    deliveries = []

    with_webpush_payload_send(->(**args) { deliveries << args }) do
      WebPushNotificationJob.perform_now(notification.id)
    end

    assert_equal 1, deliveries.size
    payload = JSON.parse(deliveries.first[:message])
    assert_equal "New message", payload["title"]
    assert_equal "/conversations/123", payload["url"]
    assert_equal "high", deliveries.first[:urgency]
    assert_equal "notification-#{notification.id}", deliveries.first[:topic]
    assert_not_nil user.web_push_subscriptions.first.last_success_at
  end

  test "removes expired subscriptions" do
    user = users(:customer)
    subscription = user.web_push_subscriptions.create!(
      endpoint: "https://push.example/subscription/expired",
      p256dh_key: "p256dh-key",
      auth_key: "auth-key"
    )
    notification = user.notifications.create!(event_type: "test", title: "Test")

    response = Struct.new(:body).new("gone")
    with_webpush_payload_send(->(**_args) { raise Webpush::ExpiredSubscription.new(response, "push.example") }) do
      WebPushNotificationJob.perform_now(notification.id)
    end

    assert_not WebPushSubscription.exists?(subscription.id)
  end

  test "records transient delivery failures without deleting subscription" do
    user = users(:customer)
    subscription = user.web_push_subscriptions.create!(
      endpoint: "https://push.example/subscription/failure",
      p256dh_key: "p256dh-key",
      auth_key: "auth-key"
    )
    notification = user.notifications.create!(event_type: "test", title: "Test")

    with_webpush_payload_send(->(**_args) { raise StandardError, "network down" }) do
      WebPushNotificationJob.perform_now(notification.id)
    end

    subscription.reload
    assert_not_nil subscription.last_failure_at
    assert_match "network down", subscription.last_error
  end

  private

  def with_webpush_payload_send(callable)
    original = Webpush.method(:payload_send)
    Webpush.define_singleton_method(:payload_send) { |**args| callable.call(**args) }
    yield
  ensure
    Webpush.define_singleton_method(:payload_send) { |**args| original.call(**args) }
  end
end
