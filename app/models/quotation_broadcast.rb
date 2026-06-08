class QuotationBroadcast < ApplicationRecord
  belongs_to :quotation
  belongs_to :created_by, class_name: "User"

  validates :minimum_rating, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 5 }
  validate :created_by_must_be_operator
  validate :vehicle_types_must_be_known

  def matching_drivers
    QuotationBroadcasts::MatchDrivers.call(broadcast: self)
  end

  private

  def created_by_must_be_operator
    return if created_by.blank? || created_by.operator?

    errors.add(:created_by, "must be an operator")
  end

  def vehicle_types_must_be_known
    invalid = Array(vehicle_types) - DriverProfile::VEHICLE_TYPES
    return if invalid.empty?

    errors.add(:vehicle_types, "include unknown vehicle types: #{invalid.join(', ')}")
  end
end
