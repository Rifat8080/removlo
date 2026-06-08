class Conversation < ApplicationRecord
  KINDS = {
    job: "job",
    support: "support"
  }.freeze

  STATUSES = {
    open: "open",
    closed: "closed"
  }.freeze

  belongs_to :conversationable, polymorphic: true, optional: true

  has_many :conversation_participants, dependent: :destroy
  has_many :participants, through: :conversation_participants, source: :user
  has_many :messages, dependent: :destroy

  enum :kind, KINDS, validate: true
  enum :status, STATUSES, default: :open, validate: true

  validates :subject, length: { maximum: 140 }, allow_blank: true
  validate :job_conversation_requires_quotation
  validate :support_conversation_must_not_have_context

  scope :recent, -> { order(last_message_at: :desc, created_at: :desc) }
  scope :for_user, ->(user) {
    where(id: ConversationParticipant.where(user_id: user.id).select(:conversation_id))
  }

  def participant_for(user)
    conversation_participants.find_by(user: user)
  end

  def unread_for?(user)
    participant = participant_for(user)
    return false if participant.blank?

    last_message = messages.where(internal_only: false).order(created_at: :desc).first
    return false if last_message.blank?

    participant.last_read_at.blank? || last_message.created_at > participant.last_read_at
  end

  def mark_read_for!(user)
    participant = participant_for(user)
    participant&.update!(last_read_at: Time.current)
  end

  def accepts_messages?
    open?
  end

  def display_subject
    subject.presence || default_subject
  end

  private

  def job_conversation_requires_quotation
    return unless job?
    return if conversationable.is_a?(Quotation)

    errors.add(:conversationable, "must be a quotation for job conversations")
  end

  def support_conversation_must_not_have_context
    return unless support? && conversationable.present?

    errors.add(:conversationable, "must be blank for support conversations")
  end

  def default_subject
    case kind
    when "job"
      "Job chat · #{conversationable&.reference || 'Move'}"
    else
      "Support chat"
    end
  end
end
