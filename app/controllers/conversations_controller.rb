class ConversationsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_conversation, only: :show

  layout "dashboard"

  def index
    authorize! :read, Conversation
    @conversations = Conversation.for_user(current_user).includes(:participants, :messages).recent
    @support_conversation = @conversations.find { |c| c.support? && c.open? }
  end

  def show
    authorize! :read, @conversation
    @conversation.mark_read_for!(current_user)
    @messages = @conversation.messages.visible_to_participants.chronological.includes(:sender)
    @message = @conversation.messages.new
  end

  def create
    if params[:quotation_id].present?
      quotation = accessible_quotation
      @conversation = Conversations::FindOrCreateJob.call(quotation: quotation, actor: current_user)
      authorize! :create, @conversation
      notice = "Job conversation opened."
    else
      authorize! :create, Conversation
      @conversation = Conversations::FindOrCreateSupport.call(
        user: current_user,
        subject: params.dig(:conversation, :subject)
      )
      notice = "Support conversation opened."
    end

    redirect_to conversation_path(@conversation), notice: notice
  rescue ActiveRecord::RecordNotFound
    redirect_to conversations_path, alert: "You do not have access to that conversation."
  rescue ActiveRecord::RecordInvalid => e
    redirect_to conversations_path, alert: e.record.errors.full_messages.to_sentence
  end

  private

  def set_conversation
    @conversation = Conversation.for_user(current_user).find(params[:id])
  end

  def accessible_quotation
    if current_user.customer?
      Quotation.for_customer(current_user).find(params[:quotation_id])
    elsif current_user.driver?
      job = Quotation.find(params[:quotation_id])
      raise ActiveRecord::RecordNotFound unless job.assigned_driver_id == current_user.id

      job
    elsif current_user.operator?
      Quotation.find(params[:quotation_id])
    else
      raise ActiveRecord::RecordNotFound
    end
  end
end
