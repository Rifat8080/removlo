class QuotationBroadcast < ApplicationRecord
  belongs_to :quotation
  belongs_to :created_by, class_name: "User"

  validates :minimum_rating, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 5 }

  def matching_drivers
    QuotationBroadcasts::MatchDrivers.call(broadcast: self)
  end
end
