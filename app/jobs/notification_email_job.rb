class NotificationEmailJob < ApplicationJob
  queue_as :default
  discard_on ActiveRecord::RecordNotFound

  def perform(notification_id)
    notification = Notification.find(notification_id)
    return if notification.user.email.blank?

    NotificationMailer.notification_email(notification).deliver_now
  end
end
