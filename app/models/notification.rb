class Notification < ApplicationRecord
  belongs_to :user
  belongs_to :actor, class_name: "User", optional: true
  belongs_to :notifiable, polymorphic: true, optional: true

  validates :event_type, :title, presence: true

  scope :recent, -> { order(created_at: :desc) }
  scope :unread, -> { where(read_at: nil) }

  after_commit :deliver_email, on: :create
  after_commit :deliver_web_push, on: :create
  after_commit :broadcast_creation, on: :create
  after_commit :broadcast_updates, on: :update

  def read?
    read_at.present?
  end

  def mark_as_read!
    update!(read_at: Time.current) unless read?
  end

  private

  def deliver_email
    NotificationEmailJob.perform_later(id)
  end

  def deliver_web_push
    if immediate_web_push?
      WebPushNotificationJob.perform_now(id)
    else
      WebPushNotificationJob.perform_later(id)
    end
  end

  def immediate_web_push?
    Rails.env.development?
  end

  def broadcast_creation
    broadcast_counts
    Turbo::StreamsChannel.broadcast_remove_to(
      user,
      :notifications,
      target: dom_id(user, :notifications_empty_state)
    )
    Turbo::StreamsChannel.broadcast_prepend_to(
      user,
      :notifications,
      target: dom_id(user, :notifications_list),
      partial: "notifications/notification",
      locals: { notification: self }
    )
  end

  def broadcast_updates
    broadcast_counts
    Turbo::StreamsChannel.broadcast_replace_to(
      user,
      :notifications,
      target: dom_id(self),
      partial: "notifications/notification",
      locals: { notification: self }
    )
  end

  def broadcast_counts
    Turbo::StreamsChannel.broadcast_replace_to(
      user,
      :notifications,
      target: dom_id(user, :notification_top_badge),
      partial: "notifications/top_badge",
      locals: { user: user }
    )
    Turbo::StreamsChannel.broadcast_replace_to(
      user,
      :notifications,
      target: dom_id(user, :notification_sidebar_badge),
      partial: "notifications/sidebar_badge",
      locals: { user: user }
    )
    Turbo::StreamsChannel.broadcast_replace_to(
      user,
      :notifications,
      target: dom_id(user, :notifications_mark_all),
      partial: "notifications/mark_all_button",
      locals: { user: user }
    )
    Turbo::StreamsChannel.broadcast_replace_to(
      user,
      :notifications,
      target: dom_id(user, :notification_dashboard_count),
      partial: "notifications/dashboard_count",
      locals: { user: user }
    )
  end

  def dom_id(record, prefix = nil)
    ActionView::RecordIdentifier.dom_id(record, prefix)
  end
end
