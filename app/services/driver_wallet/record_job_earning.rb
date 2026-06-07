module DriverWallet
  class RecordJobEarning
    def self.call(quotation:)
      new(quotation).call
    end

    def initialize(quotation)
      @quotation = quotation
    end

    def call
      return if quotation.assigned_driver.blank?
      return if quotation.driver_cost_cents.to_i <= 0
      return if DriverWalletEntry.exists?(quotation: quotation, entry_type: :job_earning)

      DriverWalletEntry.create!(
        driver: quotation.assigned_driver,
        quotation: quotation,
        entry_type: :job_earning,
        status: :pending,
        amount_cents: quotation.driver_cost_cents,
        reference: quotation.reference,
        notes: "Earnings for completed job #{quotation.reference}"
      )

      profile = DriverProfile.ensure_for!(quotation.assigned_driver)
      profile.update!(
        completed_jobs_count: profile.completed_jobs_count + 1,
        revenue_generated_cents: profile.revenue_generated_cents + quotation.driver_cost_cents
      )
    end

    private

    attr_reader :quotation
  end
end
