module Admin
  class SupportMessagesController < BaseController
    before_action :set_conversation

    def create
      @message_form_url = admin_support_conversation_messages_path(@conversation)
      @internal_only_option = true
      @message = Messages::Create.call(
        conversation: @conversation,
        sender: current_user,
        body: message_params[:body],
        internal_only: params.dig(:message, :internal_only) == "1"
      )
      @conversation.mark_read_for!(current_user)

      respond_to do |format|
        format.turbo_stream { render "messages/create", locals: { message_form_url: @message_form_url, internal_only_option: @internal_only_option } }
        format.html { redirect_to admin_support_conversation_path(@conversation) }
      end
    rescue ActiveRecord::RecordInvalid => e
      @message = e.record
      respond_to do |format|
        format.turbo_stream { render "messages/error", locals: { message_form_url: @message_form_url, internal_only_option: @internal_only_option }, status: :unprocessable_entity }
        format.html { redirect_to admin_support_conversation_path(@conversation), alert: @message.errors.full_messages.to_sentence }
      end
    rescue ActionController::ParameterMissing
      @message = @conversation.messages.new
      @message.errors.add(:body, "can't be blank")
      respond_to do |format|
        format.turbo_stream { render "messages/error", locals: { message_form_url: @message_form_url, internal_only_option: @internal_only_option }, status: :unprocessable_entity }
        format.html { redirect_to admin_support_conversation_path(@conversation), alert: "Please enter a message." }
      end
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
