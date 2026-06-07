module Admin
  class DriverOffersController < BaseController
    before_action :set_quotation
    before_action :set_offer, only: %i[select]

    def index
      @comparison = DriverOffers::Score.call(offers: @quotation.driver_offers.active.for_comparison)
    end

    def select
      @quotation.driver_offers.where.not(id: @offer.id).update_all(status: "rejected", selected_by_admin: false)
      @offer.update!(status: :selected, selected_by_admin: true)
      @quotation.update!(
        selected_driver_offer: @offer,
        driver_cost_cents: @offer.amount_cents,
        assigned_driver: @offer.driver,
        awaiting_driver_offers: false
      )

      markup = params[:markup_percentage].presence || @quotation.markup_percentage
      @quotation.apply_markup_from_driver_cost!(driver_cost_cents: @offer.amount_cents, markup_percentage: markup)

      redirect_to admin_quotation_path(@quotation), notice: "Driver offer selected and customer quote updated."
    end

    private

    def set_quotation
      @quotation = Quotation.find(params[:quotation_id])
    end

    def set_offer
      @offer = @quotation.driver_offers.find(params[:id])
    end
  end
end
