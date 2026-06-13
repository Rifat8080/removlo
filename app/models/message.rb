class Message < ApplicationRecord
  MAX_ATTACHMENTS = 5
  MAX_ATTACHMENT_SIZE = 10.megabytes
  ALLOWED_ATTACHMENT_TYPES = %w[
    application/pdf
    image/png
    image/jpeg
    image/webp
    text/plain
  ].freeze

  belongs_to :conversation
  belongs_to :sender, class_name: "User"

  has_many_attached :attachments

  validates :body, presence: true, length: { maximum: 4_000 }
  validate :attachments_must_be_safe
  validate :conversation_must_accept_messages
  validate :sender_must_participate
  validate :internal_only_requires_operator

  scope :visible_to_participants, -> { where(internal_only: false) }
  scope :chronological, -> { order(created_at: :asc) }

  after_create_commit :touch_conversation_timestamp

  def sender_label
    participant = conversation.participant_for(sender)
    participant&.display_name || sender.role.humanize
  end

  private

  def touch_conversation_timestamp
    conversation.update_column(:last_message_at, created_at)
  end

  def conversation_must_accept_messages
    return if conversation&.accepts_messages?

    errors.add(:conversation, "is closed")
  end

  def sender_must_participate
    return if conversation.blank? || sender.blank?
    return if conversation.participant_for(sender).present?

    errors.add(:sender, "must be a participant")
  end

  def internal_only_requires_operator
    return unless internal_only?
    return if sender&.operator?

    errors.add(:internal_only, "messages can only be created by operators")
  end

  def attachments_must_be_safe
    return unless attachments.attached?

    if attachments.size > MAX_ATTACHMENTS
      errors.add(:attachments, "cannot include more than #{MAX_ATTACHMENTS} files")
    end

    attachments.each do |attachment|
      unless attachment.blob.content_type.in?(ALLOWED_ATTACHMENT_TYPES)
        errors.add(:attachments, "#{attachment.filename} must be a PDF, text file, PNG, JPG, or WEBP image")
      end

      if attachment.blob.byte_size > MAX_ATTACHMENT_SIZE
        errors.add(:attachments, "#{attachment.filename} must be smaller than 10MB")
      end
    end
  end
end
