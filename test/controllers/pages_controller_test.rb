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
  ].each do |route_name|
    test "#{route_name} page renders successfully" do
      get send("#{route_name}_path")

      assert_response :success
    end
  end
end
