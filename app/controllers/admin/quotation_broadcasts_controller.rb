module Admin
  class QuotationBroadcastsController < BaseController
    before_action :set_quotation

    def create
      broadcast = @quotation.quotation_broadcasts.build(broadcast_params.merge(created_by: current_user))

      if broadcast.save
        drivers = QuotationBroadcasts::Send.call(broadcast: broadcast, actor: current_user)
        redirect_to admin_quotation_path(@quotation), notice: "Job broadcast sent to #{drivers.size} drivers."
      else
        redirect_to admin_quotation_path(@quotation), alert: broadcast.errors.full_messages.to_sentence
      end
    rescue StandardError => e
      redirect_to admin_quotation_path(@quotation), alert: "Broadcast could not be sent: #{e.message}"
    end

    private

    def set_quotation
      @quotation = Quotation.find(params[:quotation_id])
    end

    def broadcast_params
      attrs = params.require(:quotation_broadcast).permit(
        :minimum_rating,
        :require_available,
        :service_areas_text,
        vehicle_types: []
      )
      attrs[:vehicle_types] = Array(attrs[:vehicle_types]).reject(&:blank?)
      areas = attrs.delete(:service_areas_text).to_s.split(/[\s,]+/)
      attrs[:service_areas] = areas.map(&:strip).reject(&:blank?).map(&:upcase)
      attrs
    end
  end
end
