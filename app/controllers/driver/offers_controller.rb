module Driver
  class OffersController < BaseController
    before_action :set_job
    before_action :set_offer, only: %i[update accept_negotiation]

    def create
      @offer = @job.driver_offers.find_or_initialize_by(driver: current_user)
      @offer.assign_attributes(offer_params.merge(status: :submitted))
      authorize! :create, @offer

      if @offer.save
        auto_request_negotiation_for(@offer)
        notice = negotiation_notice_for(@offer) || "Your offer of #{helpers.money_from_cents(@offer.amount_cents)} was submitted."
        redirect_to driver_job_path(@job), notice: notice
      else
        redirect_to driver_job_path(@job), alert: @offer.errors.full_messages.to_sentence
      end
    end

    def update
      authorize! :update, @offer
      if @offer.update(offer_params.merge(status: :submitted))
        auto_request_negotiation_for(@offer)
        notice = negotiation_notice_for(@offer) || "Your offer was updated."
        redirect_to driver_job_path(@job), notice: notice
      else
        redirect_to driver_job_path(@job), alert: @offer.errors.full_messages.to_sentence
      end
    end

    def accept_negotiation
      authorize! :accept_negotiation, @offer
      @offer.accept_renegotiation!
      notify_operators_negotiated_bid_accepted
      redirect_to driver_job_path(@job), notice: "Negotiated price accepted. Your bid is now #{helpers.money_from_cents(@offer.amount_cents)}."
    rescue ArgumentError, ActiveRecord::RecordInvalid => e
      redirect_to driver_job_path(@job), alert: e.message
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
    rescue ArgumentError
      { amount_cents: 0 }
    end

    def notify_operators_negotiated_bid_accepted
      ::ActivityNotifier.call(
        recipients: User.operators,
        event_type: "driver_offer.negotiation_accepted",
        title: "Driver accepted negotiated price",
        body: "#{current_user.email} accepted #{@job.reference} at #{helpers.money_from_cents(@offer.amount_cents)}. The bid can now be selected.",
        url: admin_quotation_path(@job),
        actor: current_user,
        notifiable: @offer
      )
    end

    def auto_request_negotiation_for(offer)
      return unless @job.driver_negotiation_active?
      return if offer.accepted_renegotiation?

      offer.request_renegotiation!(price_cents: @job.quoted_price_cents)
      notify_driver_negotiated_bid_request(offer)
    end

    def notify_driver_negotiated_bid_request(offer)
      ::ActivityNotifier.call(
        recipients: offer.driver,
        event_type: "driver_offer.negotiation_requested",
        title: "Negotiated job price available",
        body: "#{@job.reference} has a negotiated price of #{helpers.money_from_cents(offer.renegotiation_price_cents)}. Accept it to update your bid.",
        url: driver_job_path(@job),
        actor: current_user,
        notifiable: offer
      )
    end

    def negotiation_notice_for(offer)
      return unless offer.pending_renegotiation?

      "Your bid was submitted. Accept the negotiated price of #{helpers.money_from_cents(offer.renegotiation_price_cents)} to confirm it."
    end
  end
end
