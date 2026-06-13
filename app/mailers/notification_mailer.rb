class NotificationMailer < ApplicationMailer
  helper_method :notification_destination_url

  def notification_email(notification)
    @notification = notification
    @user = notification.user

    mail(to: @user.email, subject: notification.title)
  end

  private

  def notification_destination_url
    url = @notification.url.presence
    return notifications_url if url.blank?
    return url if url.match?(%r{\Ahttps?://}i)

    URI.join(root_url, url).to_s
  end
end
