class WebPushNotificationJob < ApplicationJob
  queue_as :default

  def perform(notification_id)
    notification = Notification.find(notification_id)
    return unless web_push_configured?

    notification.user.web_push_subscriptions.find_each do |subscription|
      deliver(notification, subscription)
    end
  end

  private

  def deliver(notification, subscription)
    Webpush.payload_send(
      message: payload(notification),
      endpoint: subscription.endpoint,
      p256dh: subscription.p256dh_key,
      auth: subscription.auth_key,
      vapid: {
        subject: vapid_subject,
        public_key: vapid_public_key,
        private_key: vapid_private_key
      }
    )

    subscription.update!(last_success_at: Time.current, last_failure_at: nil, last_error: nil)
  rescue Webpush::InvalidSubscription, Webpush::ExpiredSubscription
    subscription.destroy
  rescue StandardError => e
    subscription.update!(last_failure_at: Time.current, last_error: e.message)
  end

  def payload(notification)
    {
      title: notification.title,
      body: notification.body,
      url: notification.url.presence || Rails.application.routes.url_helpers.dashboard_path,
      notification_id: notification.id
    }.to_json
  end

  def web_push_configured?
    vapid_public_key.present? && vapid_private_key.present?
  end

  def vapid_public_key
    ENV["VAPID_PUBLIC_KEY"]
  end

  def vapid_private_key
    ENV["VAPID_PRIVATE_KEY"]
  end

  def vapid_subject
    ENV.fetch("VAPID_SUBJECT", "mailto:hello@removlo.co.uk")
  end
end
