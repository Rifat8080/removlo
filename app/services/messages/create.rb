module Messages
  class Create
    def self.call(conversation:, sender:, body:, internal_only: false, attachments: nil)
      new(conversation, sender, body, internal_only, attachments).call
    end

    def initialize(conversation, sender, body, internal_only, attachments)
      @conversation = conversation
      @sender = sender
      @body = body
      @internal_only = internal_only
      @attachments = attachments
    end

    def call
      message = nil

      Conversation.transaction do
        message = conversation.messages.create!(
          sender: sender,
          body: body.to_s.strip,
          internal_only: internal_only
        )
        message.attachments.attach(attachments) if attachments.present?
      end

      notify_participants(message)
      message
    end

    private

    attr_reader :conversation, :sender, :body, :internal_only, :attachments

    def notify_participants(message)
      recipients = conversation.conversation_participants.includes(:user).filter_map do |participant|
        next if participant.user_id == sender.id
        next if message.internal_only? && !participant.user.operator?

        participant.user
      end

      ::ActivityNotifier.call(
        recipients: recipients,
        event_type: "chat.message",
        title: "New message in #{conversation.display_subject}",
        body: message.body.truncate(120),
        url: Rails.application.routes.url_helpers.conversation_path(conversation),
        actor: sender,
        notifiable: message
      )
    end
  end
end
