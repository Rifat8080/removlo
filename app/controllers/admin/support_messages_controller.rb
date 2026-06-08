module Admin
  class SupportMessagesController < BaseController
    before_action :set_conversation

    def create
      @message = Messages::Create.call(
        conversation: @conversation,
        sender: current_user,
        body: message_params[:body],
        internal_only: params.dig(:message, :internal_only) == "1"
      )
      @conversation.mark_read_for!(current_user)

      respond_to do |format|
        format.turbo_stream { render "messages/create" }
        format.html { redirect_to admin_support_conversation_path(@conversation) }
      end
    rescue ActiveRecord::RecordInvalid => e
      redirect_to admin_support_conversation_path(@conversation), alert: e.record.errors.full_messages.to_sentence
  rescue ActionController::ParameterMissing
    redirect_to admin_support_conversation_path(@conversation), alert: "Please enter a message."
    end

    private

    def set_conversation
      @conversation = Conversation.find(params[:support_conversation_id])
    end

    def message_params
      params.require(:message).permit(:body)
    end
  end
end
