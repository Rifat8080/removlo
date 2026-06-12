module Admin
  class DriverOffersController < BaseController
    before_action :set_quotation
    before_action :set_offer, only: %i[select]

    def index
      @comparison = DriverOffers::Score.call(offers: @quotation.driver_offers.active.for_comparison)
    end

    def select
      if @offer.pending_renegotiation?
        redirect_to admin_quotation_path(@quotation), alert: "This driver must accept the negotiated price before their bid can be selected."
        return
      end

      assigned_now = false
      unselected = false

      markup = current_user.admin? ? params[:markup_percentage].presence || @quotation.markup_percentage : @quotation.markup_percentage

      Quotation.transaction do
        if @quotation.selected_driver_offer == @offer
          unselect_offer!
          unselected = true
        else
          @quotation.driver_offers.where.not(id: @offer.id).find_each do |offer|
            offer.update!(status: :rejected, selected_by_admin: false)
          end
          @offer.update!(status: :selected, selected_by_admin: true)

          attrs = {
            selected_driver_offer: @offer,
            driver_cost_cents: @offer.amount_cents,
            awaiting_driver_offers: false
          }
          if @quotation.deposit_protected? || @quotation.customer_details_released?
            attrs[:assigned_driver] = @offer.driver
            assigned_now = true
          end

          @quotation.update!(attrs)
          @quotation.apply_markup_from_driver_cost!(driver_cost_cents: @offer.amount_cents, markup_percentage: markup)
        end
      end

      notice =
        if unselected
          "Driver offer unselected and bidding reopened."
        elsif assigned_now
          "Driver offer selected, assigned, and customer quote updated."
        else
          "Driver offer selected and customer quote updated. Driver assignment will unlock after deposit payment or admin release."
        end
      redirect_to admin_quotation_path(@quotation), notice: notice
    rescue ActiveRecord::RecordInvalid, ArgumentError => e
      redirect_to admin_quotation_path(@quotation), alert: e.message
    end

    private

    def unselect_offer!
      @quotation.driver_offers.rejected.find_each do |offer|
        offer.update!(status: :submitted, selected_by_admin: false)
      end

      @offer.update!(status: :submitted, selected_by_admin: false)

      attrs = {
        selected_driver_offer: nil,
        awaiting_driver_offers: true
      }
      attrs[:assigned_driver] = nil if @quotation.assigned_driver == @offer.driver

      @quotation.update!(attrs)
    end

    def set_quotation
      @quotation = Quotation.find(params[:quotation_id])
    end

    def set_offer
      @offer = @quotation.driver_offers.find(params[:id])
    end
  end
end
