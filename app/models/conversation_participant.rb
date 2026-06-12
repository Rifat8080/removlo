class ConversationParticipant < ApplicationRecord
  ROLES = %w[customer driver admin staff].freeze

  belongs_to :conversation
  belongs_to :user

  validates :participant_role, inclusion: { in: ROLES }
  validates :user_id, uniqueness: { scope: :conversation_id }

  def display_name
    case participant_role
    when "customer", "driver" then user.display_name
    when "admin", "staff" then "Support"
    else user.email
    end
  end
end
