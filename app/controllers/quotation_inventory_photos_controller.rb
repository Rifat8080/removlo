class QuotationInventoryPhotosController < ApplicationController
  before_action :authenticate_user!
  before_action :require_customer!
  before_action :set_quotation

  layout "dashboard"

  def create
    estimate = @quotation.inventory_estimate || @quotation.create_inventory_estimate!

    if params[:photos].present?
      estimate.photos.attach(params[:photos])
      estimate.update!(estimate_status: :pending, processing_status: :pending)
      estimate.enqueue_analysis!
      redirect_to quotation_path(@quotation), notice: "Inventory photos uploaded. AI analysis has been queued."
    else
      redirect_to quotation_path(@quotation), alert: "Please choose at least one photo to upload."
    end
  end

  private

  def set_quotation
    @quotation = Quotation.for_customer(current_user).find(params[:quotation_id])
  end

  def require_customer!
    return if current_user.customer?

    redirect_to dashboard_path, alert: "Only customers can upload inventory photos."
  end
end
