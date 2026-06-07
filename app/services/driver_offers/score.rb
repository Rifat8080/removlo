module DriverOffers
  class Score
    WEIGHTS = {
      price: 0.40,
      rating: 0.30,
      completion: 0.20,
      cancellation: 0.10
    }.freeze

    Result = Struct.new(:offers, :cheapest, :highest_rated, :best_value, keyword_init: true)

    def self.call(offers:)
      new(offers).call
    end

    def initialize(offers)
      @offers = Array(offers)
    end

    def call
      return Result.new(offers: [], cheapest: nil, highest_rated: nil, best_value: nil) if offers.blank?

      scored = offers.map { |offer| score_offer(offer) }
      cheapest = scored.min_by { |entry| entry[:offer].amount_cents }
      highest_rated = scored.max_by { |entry| entry[:rating] }
      best_value = scored.max_by { |entry| entry[:total_score] }

      scored.each do |entry|
        entry[:offer].update_columns(
          score: entry[:total_score],
          score_breakdown: entry[:breakdown]
        )
      end

      Result.new(
        offers: scored,
        cheapest: cheapest[:offer],
        highest_rated: highest_rated[:offer],
        best_value: best_value[:offer]
      )
    end

    private

    attr_reader :offers

    def score_offer(offer)
      profile = offer.driver.driver_profile || DriverProfile.ensure_for!(offer.driver)
      prices = offers.map(&:amount_cents)
      min_price = prices.min
      max_price = prices.max
      price_range = [max_price - min_price, 1].max
      price_score = 1.0 - ((offer.amount_cents - min_price).to_f / price_range)

      rating_score = profile.rating.to_f / 5.0
      completion_score = profile.completion_rate.to_f / 100.0
      cancellation_score = 1.0 - (profile.cancellation_rate.to_f / 100.0)

      breakdown = {
        price: (price_score * WEIGHTS[:price]).round(4),
        rating: (rating_score * WEIGHTS[:rating]).round(4),
        completion: (completion_score * WEIGHTS[:completion]).round(4),
        cancellation: (cancellation_score * WEIGHTS[:cancellation]).round(4)
      }
      total_score = breakdown.values.sum.round(4)

      {
        offer: offer,
        rating: profile.rating.to_f,
        total_score: total_score,
        breakdown: breakdown
      }
    end
  end
end
