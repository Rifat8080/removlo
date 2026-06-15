require "test_helper"

class GooglePlacesControllerTest < ActionDispatch::IntegrationTest
  test "autocomplete returns suggestions" do
    suggestions = [{ place_id: "place-1", description: "E2 8AA, London, UK" }]

    GoogleMaps::Places.stub(:autocomplete, suggestions) do
      get "/google_places/autocomplete", params: { input: "E2" }
    end

    assert_response :success
    assert_equal suggestions.as_json, response.parsed_body["suggestions"]
  end

  test "details returns postcode and formatted address" do
    details = {
      place_id: "place-1",
      formatted_address: "10 Test Street, London E2 8AA, UK",
      postcode: "E2 8AA"
    }

    GoogleMaps::Places.stub(:details, details) do
      get "/google_places/details", params: { place_id: "place-1" }
    end

    assert_response :success
    assert_equal "E2 8AA", response.parsed_body["postcode"]
    assert_equal "10 Test Street, London E2 8AA, UK", response.parsed_body["formatted_address"]
  end

  test "reverse geocode returns postcode" do
    result = {
      "results" => [
        {
          "formatted_address" => "London E2 8AA, UK",
          "address_components" => [
            { "long_name" => "E2 8AA", "short_name" => "E2 8AA", "types" => ["postal_code"] }
          ]
        }
      ]
    }

    GoogleMaps::Client.stub(:get, result) do
      get "/google_places/reverse_geocode", params: { lat: "51.5", lng: "-0.1" }
    end

    assert_response :success
    assert_equal "E2 8AA", response.parsed_body["postcode"]
  end
end
