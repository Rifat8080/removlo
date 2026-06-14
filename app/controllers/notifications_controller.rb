class NotificationsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_notification, only: :read

  layout "dashboard"

  def index
    authorize! :read, Notification
    @notifications = current_user.notifications.recent
  end

  def read
    authorize! :read, @notification
    @notification.mark_as_read!
    redirect_to @notification.url.presence || notifications_path
  end

  def read_all
    authorize! :manage, Notification
    current_user.notifications.unread.find_each(&:mark_as_read!)
    redirect_to notifications_path, notice: "All notifications marked as read."
  end

  private

  def set_notification
    @notification = current_user.notifications.find(params[:id])
  end
end
