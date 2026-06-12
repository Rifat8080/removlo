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

      broadcast_to_participants(message)
      message
    end

    private

    attr_reader :conversation, :sender, :body, :internal_only, :attachments

    def broadcast_to_participants(message)
      conversation.conversation_participants.includes(:user).find_each do |participant|
        next if participant.user_id == sender.id
        next if message.internal_only? && !participant.user.operator?

        Turbo::StreamsChannel.broadcast_remove_to(
          conversation,
          participant.user,
          :messages,
          target: ActionView::RecordIdentifier.dom_id(conversation, :empty_messages)
        )
        Turbo::StreamsChannel.broadcast_append_to(
          conversation,
          participant.user,
          :messages,
          target: ActionView::RecordIdentifier.dom_id(conversation, :messages),
          partial: "messages/message",
          locals: { message: message, viewer: participant.user }
        )
        Turbo::StreamsChannel.broadcast_append_to(
          participant.user,
          :message_alerts,
          target: ActionView::RecordIdentifier.dom_id(participant.user, :message_alerts),
          partial: "messages/alert",
          locals: { message: message }
        )
      end
    end

  end
end
