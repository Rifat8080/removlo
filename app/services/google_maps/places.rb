require "net/http"
require "json"

module GoogleMaps
  class Places
    BASE_URL = "https://places.googleapis.com/v1".freeze

    class Error < StandardError; end
    class MissingApiKeyError < Error; end

    def self.autocomplete(input)
      new.autocomplete(input)
    end

    def self.details(place_id)
      new.details(place_id)
    end

    def autocomplete(input)
      input = input.to_s.strip
      return [] if input.length < 2

      response = post_json(
        "/places:autocomplete",
        {
          input: input,
          includedRegionCodes: ["gb"],
          languageCode: "en-GB",
          regionCode: "gb"
        },
        field_mask: "suggestions.placePrediction.placeId,suggestions.placePrediction.text.text"
      )

      Array(response["suggestions"]).filter_map do |suggestion|
        prediction = suggestion["placePrediction"]
        next if prediction.blank?

        {
          place_id: prediction["placeId"],
          description: prediction.dig("text", "text")
        }
      end
    end

    def details(place_id)
      place_id = place_id.to_s.strip
      raise Error, "Missing place id" if place_id.blank?

      response = get_json(
        "/places/#{URI.encode_www_form_component(place_id)}",
        field_mask: "id,formattedAddress,addressComponents"
      )

      {
        place_id: response["id"],
        formatted_address: response["formattedAddress"],
        postcode: postcode_from(response["addressComponents"])
      }
    end

    private

    def api_key
      ENV["GOOGLE_MAPS_SERVER_KEY"].presence || raise(MissingApiKeyError, "GOOGLE_MAPS_SERVER_KEY is not configured")
    end

    def post_json(path, body, field_mask:)
      request = Net::HTTP::Post.new(path, headers(field_mask).merge("Content-Type" => "application/json"))
      request.body = JSON.generate(body)
      perform(request)
    end

    def get_json(path, field_mask:)
      perform(Net::HTTP::Get.new(path, headers(field_mask)))
    end

    def headers(field_mask)
      {
        "X-Goog-Api-Key" => api_key,
        "X-Goog-FieldMask" => field_mask
      }
    end

    def perform(request)
      uri = URI("#{BASE_URL}#{request.path}")

      response = Net::HTTP.start(uri.host, uri.port, use_ssl: true, cert_store: GoogleMaps::Client.cert_store) do |http|
        http.open_timeout = 5
        http.read_timeout = 8
        http.request(request)
      end

      payload = JSON.parse(response.body.presence || "{}")
      return payload if response.is_a?(Net::HTTPSuccess)

      message = payload.dig("error", "message").presence || "Google Places request failed (#{response.code})"
      raise Error, message
    rescue JSON::ParserError => e
      raise Error, "Invalid Google Places response: #{e.message}"
    rescue Net::OpenTimeout, Net::ReadTimeout, SocketError, OpenSSL::SSL::SSLError => e
      raise Error, "Google Places request could not be completed: #{e.message}"
    end

    def postcode_from(address_components)
      Array(address_components).find { |component| Array(component["types"]).include?("postal_code") }&.then do |component|
        component["longText"].presence || component["shortText"].presence
      end
    end
  end
end
