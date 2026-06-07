class Message < ApplicationRecord
  belongs_to :conversation
  belongs_to :sender, class_name: "User"

  has_many_attached :attachments

  validates :body, presence: true

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

end
