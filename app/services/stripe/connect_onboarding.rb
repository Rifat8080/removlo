module Stripe
  class ConnectOnboarding
    class Error < StandardError; end

    def self.call(driver:, return_url:, refresh_url:)
      new(driver, return_url: return_url, refresh_url: refresh_url).call
    end

    def initialize(driver, return_url:, refresh_url:)
      @driver = driver
      @return_url = return_url
      @refresh_url = refresh_url
    end

    def call
      raise Error, "Stripe is not configured." if Stripe.api_key.blank?

      profile = DriverProfile.ensure_for!(driver)
      account_id = profile.stripe_account_id

      if account_id.blank?
        account = Stripe::Account.create(
          type: "express",
          country: "GB",
          email: driver.email,
          capabilities: {
            transfers: { requested: true }
          },
          metadata: {
            driver_id: driver.id
          }
        )
        account_id = account.id
        profile.update!(
          stripe_account_id: account_id,
          stripe_onboarding_status: "pending"
        )
      end

      account_link = Stripe::AccountLink.create(
        account: account_id,
        refresh_url: refresh_url,
        return_url: return_url,
        type: "account_onboarding"
      )

      account_link.url
    end

    private

    attr_reader :driver, :return_url, :refresh_url
  end
end
