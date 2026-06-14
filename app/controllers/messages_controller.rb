class MessagesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_conversation

  def create
    draft_message = @conversation.messages.new(sender: current_user, internal_only: internal_only?)
    authorize! internal_only? ? :create_internal : :create, draft_message

    @message = Messages::Create.call(
      conversation: @conversation,
      sender: current_user,
      body: message_params[:body],
      internal_only: internal_only?,
      attachments: params.dig(:message, :attachments)
    )
    @conversation.mark_read_for!(current_user)

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to conversation_path(@conversation) }
    end
  rescue ActiveRecord::RecordInvalid => e
    @message = e.record
    respond_to do |format|
      format.turbo_stream { render :error, status: :unprocessable_entity }
      format.html { redirect_to conversation_path(@conversation), alert: @message.errors.full_messages.to_sentence }
    end
  rescue ActionController::ParameterMissing
    @message = @conversation.messages.new
    @message.errors.add(:body, "can't be blank")
    respond_to do |format|
      format.turbo_stream { render :error, status: :unprocessable_entity }
      format.html { redirect_to conversation_path(@conversation), alert: "Please enter a message." }
    end
  end

  private

  def set_conversation
    @conversation = Conversation.for_user(current_user).find(params[:conversation_id])
  end

  def message_params
    params.require(:message).permit(:body)
  end

  def internal_only?
    current_user.operator? && params.dig(:message, :internal_only) == "1"
  end
end
