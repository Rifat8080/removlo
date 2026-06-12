module GoogleMaps
  class ApplyRouteEstimate
    def self.call(quotation:)
      new(quotation).call
    end

    def initialize(quotation)
      @quotation = quotation
    end

    def call
      result = RouteEstimator.call(quotation: quotation)

      if result
        quotation.update!(
          pickup_latitude: result.pickup_latitude,
          pickup_longitude: result.pickup_longitude,
          delivery_latitude: result.delivery_latitude,
          delivery_longitude: result.delivery_longitude,
          route_distance_meters: result.distance_meters,
          route_duration_seconds: result.duration_seconds,
          route_summary: result.summary,
          route_polyline: result.polyline,
          route_estimated_at: Time.current,
          route_estimate_error: nil
        )
      else
        quotation.update!(
          route_estimate_error: Client.configured? ? "Could not estimate route" : "Google Maps server key not configured",
          route_estimated_at: Time.current
        )
      end

      quotation
    end

    private

    attr_reader :quotation
  end
end
