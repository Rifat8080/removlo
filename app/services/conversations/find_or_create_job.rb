module Conversations
  class FindOrCreateJob
    def self.call(quotation:, actor:)
      new(quotation, actor).call
    end

    def initialize(quotation, actor)
      @quotation = quotation
      @actor = actor
    end

    def call
      raise ActiveRecord::RecordNotFound, "Job chat unavailable" unless chat_allowed?

      conversation = Conversation.find_or_create_by!(conversationable: quotation, kind: :job) do |record|
        record.subject = "Job chat · #{quotation.reference}"
        record.status = :open
      end

      ensure_participants!(conversation)
      conversation
    end

    private

    attr_reader :quotation, :actor

    def chat_allowed?
      quotation.customer_details_releasable? && quotation.assigned_driver.present?
    end

    def ensure_participants!(conversation)
      add_participant(conversation, quotation.customer, "customer")
      add_participant(conversation, quotation.assigned_driver, "driver")
      User.operators.find_each do |operator|
        add_participant(conversation, operator, operator.role)
      end
    end

    def add_participant(conversation, user, role)
      return if user.blank?

      conversation.conversation_participants.find_or_create_by!(user: user) do |participant|
        participant.participant_role = role
      end
    end
  end
end
