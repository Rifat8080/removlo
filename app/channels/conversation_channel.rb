class ConversationChannel < ApplicationCable::Channel
  def subscribed
    conversation = Conversation.for_user(current_user).find_by(id: params[:conversation_id])
    reject unless conversation

    stream_for conversation
  end

  def unsubscribed
    stop_all_streams
  end
end
