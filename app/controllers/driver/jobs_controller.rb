module Driver
  class JobsController < BaseController
    before_action :set_job, only: %i[show start complete]
    before_action :require_assigned_driver!, only: %i[start complete]

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

    def start
      @job.transition_to!(:in_progress, actor: current_user, note: "Driver started the move")
      notify_customer("Move started", "Your Removlo driver has started #{@job.reference}.")
      redirect_to driver_job_path(@job), notice: "Move started."
    rescue ActiveRecord::RecordInvalid, ArgumentError => e
      redirect_to driver_job_path(@job), alert: e.message
    end

    def complete
      @job.transition_to!(:completed, actor: current_user, note: "Driver completed the move")
      DriverWallet::RecordJobEarning.call(quotation: @job)
      notify_customer("Move completed", "Your Removlo move #{@job.reference} has been completed.")
      redirect_to driver_job_path(@job), notice: "Move completed."
    rescue ActiveRecord::RecordInvalid, ArgumentError => e
      redirect_to driver_job_path(@job), alert: e.message
    end

    private

    def set_job
      @job = Quotation.find(params[:id])
      return if @job.assigned_driver == current_user || @job.awaiting_driver_offers?

      redirect_to driver_jobs_path, alert: "You do not have access to this job."
    end

    def require_assigned_driver!
      return if @job.assigned_driver == current_user

      redirect_to driver_jobs_path, alert: "Only the assigned driver can update this job."
    end

    def notify_customer(title, body)
      ::ActivityNotifier.call(
        recipients: @job.customer,
        event_type: "quotation.driver_activity",
        title: title,
        body: body,
        url: quotation_path(@job),
        actor: current_user,
        notifiable: @job
      )
    end
  end
end
