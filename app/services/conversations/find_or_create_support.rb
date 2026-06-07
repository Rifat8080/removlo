module Conversations
  class FindOrCreateSupport
    def self.call(user:, subject: nil)
      new(user, subject).call
    end

    def initialize(user, subject)
      @user = user
      @subject = subject
    end

    def call
      conversation = Conversation.create!(
        kind: :support,
        subject: subject.presence || "Support request",
        status: :open
      )

      conversation.conversation_participants.create!(user: user, participant_role: user.role)
      User.operators.find_each do |operator|
        conversation.conversation_participants.find_or_create_by!(user: operator) do |participant|
          participant.participant_role = operator.role
        end
      end

      conversation
    end

    private

    attr_reader :user, :subject
  end
end
