module Admin
  class DriverPerformancesController < BaseController
    def index
      @summaries = User.drivers.includes(:driver_profile).order(:email).map do |driver|
        DriverProfiles::PerformanceSummary.call(driver: driver)
      end
    end

    def show
      @driver = User.drivers.find(params[:id])
      @summary = DriverProfiles::PerformanceSummary.call(driver: @driver)
      @recent_jobs = @driver.driver_jobs.recent.limit(10)
      @recent_offers = @driver.driver_offers.includes(:quotation).recent.limit(10)
    end
  end
end
