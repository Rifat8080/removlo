module Admin
  class InventoryEstimatesController < BaseController
    before_action :set_quotation
    before_action :set_estimate

    def update
      if @estimate.update(estimate_params)
        @estimate.update!(estimate_status: :reviewed, processing_status: :completed) if @estimate.estimated_inventory.present?
        redirect_to admin_quotation_path(@quotation), notice: "Inventory estimate updated."
      else
        redirect_to admin_quotation_path(@quotation), alert: @estimate.errors.full_messages.to_sentence
      end
    end

    private

    def set_quotation
      @quotation = Quotation.find(params[:quotation_id])
    end

    def set_estimate
      @estimate = @quotation.inventory_estimate || @quotation.create_inventory_estimate!
    end

    def estimate_params
      attrs = params.require(:quotation_inventory_estimate).permit(:suggested_vehicle, :admin_notes, :estimate_status)
      if params[:inventory_items].present?
        attrs[:estimated_inventory] = params[:inventory_items].values.map do |item|
          next if item[:name].blank?

          { name: item[:name], quantity: item[:quantity].presence || 1 }
        end.compact
        attrs[:estimate_status] = "estimated"
      end
      attrs
    end
  end
end
