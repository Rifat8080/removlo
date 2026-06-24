require "test_helper"

class PagesControllerTest < ActionDispatch::IntegrationTest
  %i[
    root
    services
    home_removals
    office_removals
    packing_services
    storage_solutions
    how_it_works
    about
    reviews
    contact
    get_quotation
  ].each do |route_name|
    test "#{route_name} page renders successfully" do
      get send("#{route_name}_path")

      assert_response :success
    end
  end

  test "seo landing page renders like the homepage" do
    get seo_landing_path("removal-company-near-me")

    assert_response :success
    assert_includes response.body, "Removal Company Near Me,"
    assert_includes response.body, "Get your free quote"
    assert_includes response.body, "Frequently asked questions"
  end

  test "unknown seo landing slug returns not found" do
    get "/uk/unknown-seo-page"

    assert_response :not_found
  end
end
