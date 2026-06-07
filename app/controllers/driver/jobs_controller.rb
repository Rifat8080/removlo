module Driver
  class JobsController < BaseController
    before_action :set_job, only: :show

    def index
      @assigned_jobs = Quotation.for_driver(current_user).recent
      @open_jobs = Quotation.awaiting_driver.recent
      @my_offers = current_user.driver_offers.includes(:quotation).recent
    end

    def show
      @offer = @job.driver_offers.find_by(driver: current_user) || @job.driver_offers.new
      @job_chat_available = @job.assigned_driver == current_user && @job.customer_details_releasable?
      @job_conversation = @job.job_conversation if @job_chat_available
      @job_chat_messages = @job_conversation&.messages&.visible_to_participants&.chronological || []
    end

    private

    def set_job
      @job = Quotation.find(params[:id])
      return if @job.assigned_driver == current_user || @job.awaiting_driver_offers?

      redirect_to driver_jobs_path, alert: "You do not have access to this job."
    end
  end
end
