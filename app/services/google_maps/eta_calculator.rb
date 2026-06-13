module GoogleMaps
  class EtaCalculator
    Result = Data.define(:eta_seconds, :distance_meters, :destination_label)

    def self.call(quotation:, latitude:, longitude:)
      new(quotation, latitude, longitude).call
    end

    def initialize(quotation, latitude, longitude)
      @quotation = quotation
      @latitude = latitude
      @longitude = longitude
    end

    def call
      return nil unless Client.configured?

      destination = destination_query
      return nil if destination.blank?

      payload = Client.get(
        "distancematrix/json",
        origins: "#{latitude},#{longitude}",
        destinations: destination,
        mode: "driving"
      )
      unless payload["status"] == "OK"
        Rails.logger.warn("[GoogleMaps::EtaCalculator] Distance Matrix #{payload["status"]}: #{payload["error_message"]}")
        return nil
      end

      element = payload.dig("rows", 0, "elements", 0)
      unless element && element["status"] == "OK"
        Rails.logger.warn("[GoogleMaps::EtaCalculator] Distance Matrix element #{element&.dig("status") || "missing"}")
        return nil
      end

      Result.new(
        eta_seconds: element.dig("duration", "value"),
        distance_meters: element.dig("distance", "value"),
        destination_label: destination_label
      )
    rescue Client::Error => e
      Rails.logger.warn("[GoogleMaps::EtaCalculator] #{e.message}")
      nil
    end

    private

    attr_reader :quotation, :latitude, :longitude

    def destination_query
      quotation.tracking_destination_query
    end

    def destination_label
      quotation.in_progress? ? "Delivery" : "Pickup"
    end
  end
end
