class MessageAttachmentsController < ApplicationController
  before_action :authenticate_user!

  def show
    conversation = Conversation.for_user(current_user).find(params[:conversation_id])
    message = conversation.messages.find(params[:message_id])
    attachment = message.attachments.find(params[:id])

    redirect_to rails_blob_path(attachment, disposition: "attachment"), allow_other_host: false
  end
end
