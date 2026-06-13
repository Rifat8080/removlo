module Driver
  class JobsController < BaseController
    before_action :set_job, only: %i[show start complete cancel_assignment]
    before_action :require_assigned_driver!, only: %i[start complete cancel_assignment]

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

    def cancel_assignment
      if @job.in_progress? || @job.completed?
        redirect_to driver_job_path(@job), alert: "You cannot cancel this job after the move has started."
        return
      end

      Quotation.transaction do
        @job.driver_offers.rejected.update_all(status: DriverOffer.statuses[:submitted], selected_by_admin: false)
        @job.selected_driver_offer&.update!(status: :withdrawn, selected_by_admin: false)
        @job.update!(assigned_driver: nil, selected_driver_offer: nil, awaiting_driver_offers: true)
      end

      notify_operators_driver_cancelled
      redirect_to driver_jobs_path, notice: "Your assignment was cancelled. Removlo has been notified."
    rescue ActiveRecord::RecordInvalid => e
      redirect_to driver_job_path(@job), alert: e.record.errors.full_messages.to_sentence
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

    def notify_operators_driver_cancelled
      ::ActivityNotifier.call(
        recipients: User.operators,
        event_type: "quotation.driver_cancelled",
        title: "Driver cancelled assignment",
        body: "#{current_user.email} cancelled their assignment for #{@job.reference}. Reassign a driver or wait for new bids.",
        url: admin_quotation_path(@job),
        actor: current_user,
        notifiable: @job
      )
    end
  end
end
