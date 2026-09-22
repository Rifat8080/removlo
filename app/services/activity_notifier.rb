class ActivityNotifier
  def self.call(...)
    new(...).call
  end

  def initialize(recipients:, event_type:, title:, body: nil, url: nil, actor: nil, notifiable: nil, metadata: {})
    @recipients = Array(recipients).compact.uniq
    @event_type = event_type
    @title = title
    @body = body
    @url = url
    @actor = actor
    @notifiable = notifiable
    @metadata = metadata
  end

  def call
    recipients.filter_map do |recipient|
      next if actor.present? && recipient == actor

      create_notification(recipient)
    end
  end

  private

  attr_reader :recipients, :event_type, :title, :body, :url, :actor, :notifiable, :metadata

  def create_notification(recipient)
    Notification.create!(
      user: recipient,
      actor: actor,
      event_type: event_type,
      title: title,
      body: body,
      url: url,
      notifiable: notifiable,
      metadata: metadata
    )
  rescue StandardError => e
    Rails.logger.error("[ActivityNotifier] Notification failed for user #{recipient.id}: #{e.class}: #{e.message}")
    nil
  end
end
