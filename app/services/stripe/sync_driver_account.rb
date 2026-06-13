module Stripe
  class SyncDriverAccount
    def self.call(profile)
      new(profile).call
    end

    def initialize(profile)
      @profile = profile
    end

    def call
      return profile if profile.stripe_account_id.blank? || Stripe.api_key.blank?

      account = Stripe::Account.retrieve(profile.stripe_account_id)
      profile.sync_stripe_account!(account)
      profile
    rescue Stripe::StripeError => e
      Rails.logger.error("[Stripe::SyncDriverAccount] #{e.class}: #{e.message}")
      profile
    end

    private

    attr_reader :profile
  end
end
