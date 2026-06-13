require "net/http"
require "json"
require "openssl"

module GoogleMaps
  class Client
    BASE_URL = "https://maps.googleapis.com/maps/api".freeze

    class Error < StandardError; end
    class MissingApiKeyError < Error; end

    def self.api_key
      ENV["GOOGLE_MAPS_SERVER_KEY"].presence || ENV["GOOGLE_MAPS_API_KEY"].presence
    end

    def self.configured?
      api_key.present?
    end

    def self.get(path, params = {})
      key = api_key
      raise MissingApiKeyError, "GOOGLE_MAPS_SERVER_KEY is not configured" if key.blank?

      uri = URI("#{BASE_URL}/#{path}")
      uri.query = URI.encode_www_form(params.merge(key: key))

      response = Net::HTTP.start(uri.host, uri.port, use_ssl: true, cert_store: cert_store) do |http|
        http.open_timeout = 5
        http.read_timeout = 8
        http.get(uri.request_uri)
      end
      raise Error, "Google Maps request failed (#{response.code})" unless response.is_a?(Net::HTTPSuccess)

      JSON.parse(response.body)
    rescue JSON::ParserError => e
      raise Error, "Invalid Google Maps response: #{e.message}"
    rescue Net::OpenTimeout, Net::ReadTimeout, SocketError, OpenSSL::SSL::SSLError => e
      raise Error, "Google Maps request could not be completed: #{e.message}"
    end

    def self.cert_store
      store = OpenSSL::X509::Store.new
      store.set_default_paths
      store
    end
  end
end
