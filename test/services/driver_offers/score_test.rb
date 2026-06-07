require "test_helper"

class DriverOffersScoreTest < ActiveSupport::TestCase
  test "identifies cheapest highest rated and best value offers" do
    quotation = quotations(:marketplace_job)
    offers = quotation.driver_offers.active.for_comparison.to_a

    result = DriverOffers::Score.call(offers: offers)

    assert_equal driver_offers(:offer_a), result.cheapest
    assert_equal driver_offers(:offer_a), result.highest_rated
    assert result.best_value.present?
    assert result.offers.all? { |entry| entry[:total_score].positive? }
  end
end
