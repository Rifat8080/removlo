module DriverProfiles
  class PerformanceSummary
    Summary = Struct.new(:driver, :profile, :jobs_count, :revenue_cents, :cancellation_rate, :late_arrivals, keyword_init: true)

    def self.call(driver:)
      new(driver).call
    end

    def initialize(driver)
      @driver = driver
    end

    def call
      profile = DriverProfile.ensure_for!(driver)
      jobs_count = driver.driver_jobs.completed.count
      revenue_cents = profile.revenue_generated_cents.positive? ? profile.revenue_generated_cents : driver.driver_wallet_entries.credits.sum(:amount_cents)

      Summary.new(
        driver: driver,
        profile: profile,
        jobs_count: jobs_count,
        revenue_cents: revenue_cents,
        cancellation_rate: profile.cancellation_rate,
        late_arrivals: profile.late_arrivals_count
      )
    end

    private

    attr_reader :driver
  end
end
