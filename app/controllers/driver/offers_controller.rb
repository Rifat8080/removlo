module Driver
  class OffersController < BaseController
    before_action :set_job
    before_action :set_offer, only: :update

    def create
      @offer = @job.driver_offers.find_or_initialize_by(driver: current_user)
      @offer.assign_attributes(offer_params.merge(status: :submitted))

      if @offer.save
        redirect_to driver_job_path(@job), notice: "Your offer of #{helpers.money_from_cents(@offer.amount_cents)} was submitted."
      else
        redirect_to driver_job_path(@job), alert: @offer.errors.full_messages.to_sentence
      end
    end

    def update
      if @offer.update(offer_params.merge(status: :submitted))
        redirect_to driver_job_path(@job), notice: "Your offer was updated."
      else
        redirect_to driver_job_path(@job), alert: @offer.errors.full_messages.to_sentence
      end
    end

    private

    def set_job
      @job = Quotation.find(params[:job_id])
      return if @job.awaiting_driver_offers? || @job.assigned_driver == current_user

      redirect_to driver_jobs_path, alert: "This job is not open for offers."
    end

    def set_offer
      @offer = @job.driver_offers.find_by!(driver: current_user)
    end

    def offer_params
      attrs = params.require(:driver_offer).permit(:amount)
      amount = BigDecimal(attrs.delete(:amount).presence || "0") * 100
      { amount_cents: amount.to_i }
    end
  end
end
