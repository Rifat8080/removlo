module Admin
  class SupportConversationsController < BaseController
    before_action :set_conversation, only: %i[show close reopen]

    def index
      authorize! :read, Conversation
      @support_conversations = Conversation.support.open.recent.includes(:participants, :messages)
      @job_conversations = Conversation.job.open.recent.includes(:conversationable, :participants, :messages).limit(20)
    end

    def show
      authorize! :read, @conversation
      @messages = @conversation.messages.chronological.includes(:sender)
      @message = @conversation.messages.new
      @conversation.mark_read_for!(current_user)
    end

    def close
      authorize! :update, @conversation
      @conversation.update!(status: :closed)
      redirect_to admin_support_conversation_path(@conversation), notice: "Conversation closed."
    end

    def reopen
      authorize! :update, @conversation
      @conversation.update!(status: :open)
      redirect_to admin_support_conversation_path(@conversation), notice: "Conversation reopened."
    end

    private

    def set_conversation
      @conversation = Conversation.find(params[:id])
    end
  end
end
