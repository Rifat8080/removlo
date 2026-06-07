class DriverProfile < ApplicationRecord
  VEHICLE_TYPES = %w[luton_van 7_5_ton_luton transit_van large_van].freeze

  belongs_to :user

  validates :vehicle_type, inclusion: { in: VEHICLE_TYPES }
  validates :rating, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 5 }
  validates :completion_rate, :cancellation_rate, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 100 }

  def self.ensure_for!(driver)
    return driver.driver_profile if driver.driver_profile.present?

    driver.create_driver_profile!
  end

  def matches_vehicle?(required_vehicle)
    required_vehicle.blank? || vehicle_type == required_vehicle.to_s
  end

  def matches_service_area?(postcode)
    return true if service_areas.blank?

    area = postcode.to_s.strip.upcase
    service_areas.any? { |candidate| area.start_with?(candidate.to_s.upcase) }
  end

  def available_on?(date)
    return true if date.blank?

    availability = user.driver_availabilities.find_by(available_on: date)
    availability.blank? || availability.available?
  end
end
