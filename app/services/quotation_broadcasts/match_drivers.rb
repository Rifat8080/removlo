module QuotationBroadcasts
  class MatchDrivers
    def self.call(broadcast:)
      new(broadcast).call
    end

    def initialize(broadcast)
      @broadcast = broadcast
      @quotation = broadcast.quotation
    end

    def call
      User.drivers.includes(:driver_profile, :driver_availabilities).select do |driver|
        profile = DriverProfile.ensure_for!(driver)
        matches_vehicle?(profile) &&
          matches_service_area?(profile) &&
          matches_rating?(profile) &&
          matches_availability?(driver)
      end
    end

    private

    attr_reader :broadcast, :quotation

    def matches_vehicle?(profile)
      return true if broadcast.vehicle_types.blank?

      broadcast.vehicle_types.include?(profile.vehicle_type)
    end

    def matches_service_area?(profile)
      return true if broadcast.service_areas.blank?

      pickup_match = broadcast.service_areas.any? { |area| profile.matches_service_area?(area) }
      delivery_match = broadcast.service_areas.any? { |area| profile.matches_service_area?(area) }
      pickup_match || delivery_match || profile.matches_service_area?(quotation.pickup_postcode) || profile.matches_service_area?(quotation.delivery_postcode)
    end

    def matches_rating?(profile)
      profile.rating.to_f >= broadcast.minimum_rating.to_f
    end

    def matches_availability?(driver)
      return true unless broadcast.require_available?

      date = quotation.preferred_move_date || quotation.scheduled_at&.to_date || Date.current
      driver.driver_availabilities.where(available_on: date).none? ||
        driver.driver_availabilities.available_on_date(date).exists?
    end
  end
end
