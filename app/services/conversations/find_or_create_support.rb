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
      conversation = Conversation.support.open.for_user(user).first
      conversation ||= Conversation.create!(
        kind: :support,
        subject: subject.presence || "Support request",
        status: :open
      )

      conversation.conversation_participants.find_or_create_by!(user: user) do |participant|
        participant.participant_role = user.role
      end
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
