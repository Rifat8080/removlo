class NotificationsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_notification, only: :read

  layout "dashboard"

  def index
    @notifications = current_user.notifications.recent
  end

  def read
    @notification.mark_as_read!
    redirect_to @notification.url.presence || notifications_path
  end

  def read_all
    current_user.notifications.unread.update_all(read_at: Time.current, updated_at: Time.current)
    redirect_to notifications_path, notice: "All notifications marked as read."
  end

  private

  def set_notification
    @notification = current_user.notifications.find(params[:id])
  end
end
