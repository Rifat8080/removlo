class WebPushNotificationJob < ApplicationJob
  queue_as :default
  discard_on ActiveRecord::RecordNotFound

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
      ttl: 12.hours.to_i,
      urgency: urgency_for(notification),
      topic: topic_for(notification),
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
    subscription.update!(last_failure_at: Time.current, last_error: "#{e.class}: #{e.message}".truncate(500))
  end

  def payload(notification)
    {
      title: notification.title,
      body: notification.body.to_s.truncate(180),
      url: notification_url(notification),
      notification_id: notification.id,
      event_type: notification.event_type,
      tag: topic_for(notification),
      timestamp: notification.created_at.to_i * 1000,
      unread_count: notification.user.unread_notifications_count,
      icon: "/icon.svg",
      badge: "/icon.svg",
      actions: [
        { action: "open", title: "Open" }
      ]
    }.to_json
  end

  def notification_url(notification)
    notification.url.presence || Rails.application.routes.url_helpers.notifications_path
  end

  def topic_for(notification)
    "notification-#{notification.id}"
  end

  def urgency_for(notification)
    case notification.event_type
    when /driver_job_alert|payment|assigned/
      "high"
    else
      "normal"
    end
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
    ENV.fetch("VAPID_SUBJECT", "mailto:support@removlo.co.uk").strip.gsub(/\Amailto:\s+/, "mailto:")
  end
end
