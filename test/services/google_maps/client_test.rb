require "test_helper"

class GoogleMaps::ClientTest < ActiveSupport::TestCase
  test "wraps SSL failures in recoverable Google Maps error" do
    ENV["GOOGLE_MAPS_SERVER_KEY"] = "test-key"

    Net::HTTP.stub(:start, ->(*_args, **_kwargs) { raise OpenSSL::SSL::SSLError, "certificate verify failed" }) do
      error = assert_raises(GoogleMaps::Client::Error) do
        GoogleMaps::Client.get("distancematrix/json")
      end

      assert_match "could not be completed", error.message
    end
  ensure
    ENV.delete("GOOGLE_MAPS_SERVER_KEY")
  end
end
