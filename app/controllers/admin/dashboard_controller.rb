module Admin
  class DashboardController < BaseController
    def index
      @lead_counts = {
        new_leads: Quotation.new_leads.count,
        pending_quotes: Quotation.pending_quotes.count,
        awaiting_driver: Quotation.awaiting_driver.count,
        booked_jobs: Quotation.booked_jobs.count,
        completed: Quotation.completed.count
      }
      @recent_quotations = Quotation.includes(:customer, :assigned_driver).recent.limit(8)
      @pending_payouts = DriverWalletEntry.where(status: "available").where("amount_cents > 0").includes(:driver).limit(6)
      @driver_performance = User.drivers.includes(:driver_profile).limit(6).map do |driver|
        DriverProfiles::PerformanceSummary.call(driver: driver)
      end
    end
  end
end
