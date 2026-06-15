class GooglePlacesController < ApplicationController
  rescue_from GoogleMaps::Places::Error, GoogleMaps::Places::MissingApiKeyError, with: :places_error

  def autocomplete
    input = params[:input].to_s.strip.first(120)
    render json: { suggestions: GoogleMaps::Places.autocomplete(input) }
  end

  def details
    render json: GoogleMaps::Places.details(params[:place_id])
  end

  def reverse_geocode
    result = GoogleMaps::Client.get(
      "geocode/json",
      latlng: "#{params[:lat]},#{params[:lng]}",
      components: "country:GB"
    )
    address = Array(result["results"]).find { |item| postcode_from(item["address_components"]).present? } || result["results"]&.first

    render json: {
      formatted_address: address&.dig("formatted_address"),
      postcode: postcode_from(address&.dig("address_components"))
    }
  rescue GoogleMaps::Client::Error, GoogleMaps::Client::MissingApiKeyError => e
    render json: { error: e.message }, status: :service_unavailable
  end

  private

  def places_error(error)
    render json: { error: error.message }, status: :service_unavailable
  end

  def postcode_from(address_components)
    Array(address_components).find { |component| Array(component["types"]).include?("postal_code") }&.then do |component|
      component["long_name"].presence || component["short_name"].presence
    end
  end
end
