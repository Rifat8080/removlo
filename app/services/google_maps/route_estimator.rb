module GoogleMaps
  class RouteEstimator
    Result = Data.define(
      :pickup_latitude,
      :pickup_longitude,
      :delivery_latitude,
      :delivery_longitude,
      :distance_meters,
      :duration_seconds,
      :summary,
      :polyline
    )

    def self.call(quotation:)
      new(quotation).call
    end

    def initialize(quotation)
      @quotation = quotation
    end

    def call
      return nil unless Client.configured?

      pickup = geocode(pickup_query)
      delivery = geocode(delivery_query)
      return nil unless pickup && delivery

      directions = fetch_directions(pickup, delivery)
      return nil unless directions

      Result.new(
        pickup_latitude: pickup[:lat],
        pickup_longitude: pickup[:lng],
        delivery_latitude: delivery[:lat],
        delivery_longitude: delivery[:lng],
        distance_meters: directions[:distance_meters],
        duration_seconds: directions[:duration_seconds],
        summary: directions[:summary],
        polyline: directions[:polyline]
      )
    rescue Client::Error => e
      Rails.logger.warn("[GoogleMaps::RouteEstimator] #{e.message}")
      nil
    end

    private

    attr_reader :quotation

    def pickup_query
      [quotation.pickup_address, quotation.pickup_postcode, "UK"].compact_blank.join(", ")
    end

    def delivery_query
      [quotation.delivery_address, quotation.delivery_postcode, "UK"].compact_blank.join(", ")
    end

    def geocode(address)
      return nil if address.blank?

      payload = Client.get("geocode/json", address: address, region: "gb")
      return nil unless payload["status"] == "OK" && payload["results"].present?

      location = payload["results"].first.dig("geometry", "location")
      return nil unless location

      { lat: location["lat"], lng: location["lng"] }
    end

    def fetch_directions(origin, destination)
      payload = Client.get(
        "directions/json",
        origin: "#{origin[:lat]},#{origin[:lng]}",
        destination: "#{destination[:lat]},#{destination[:lng]}",
        mode: "driving",
        region: "gb"
      )
      return nil unless payload["status"] == "OK" && payload["routes"].present?

      leg = payload["routes"].first["legs"].first
      return nil unless leg

      {
        distance_meters: leg.dig("distance", "value"),
        duration_seconds: leg.dig("duration", "value"),
        summary: payload["routes"].first["summary"],
        polyline: payload["routes"].first.dig("overview_polyline", "points")
      }
    end
  end
end
