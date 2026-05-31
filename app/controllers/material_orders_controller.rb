class MaterialOrdersController < ApplicationController
  before_action :authenticate_user!
  before_action :set_order, only: %i[show pdf]

  layout "dashboard"

  def index
    @orders = current_user.material_orders.recent.includes(:material_order_items)
  end

  def show
    authorize_order!
  end

  def pdf
    authorize_order!
    send_data(
      Pdf::MaterialOrderPdf.new(@order).render,
      filename: "#{@order.order_number.parameterize}.pdf",
      type: "application/pdf",
      disposition: "attachment"
    )
  end

  private

  def set_order
    @order = MaterialOrder.includes(:material_order_items).find(params[:id])
  end

  def authorize_order!
    return if @order.customer_id == current_user.id

    redirect_to material_orders_path, alert: "You are not authorized to view this order."
  end
end
