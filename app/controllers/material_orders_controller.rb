class MaterialOrdersController < ApplicationController
  before_action :authenticate_user!
  before_action :set_order, only: %i[show pdf]

  layout "dashboard"

  def index
    authorize! :read, MaterialOrder
    @orders = current_user.material_orders.recent.includes(:material_order_items)
  end

  def show
    authorize! :read, @order
  end

  def pdf
    authorize! :pdf, @order
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
end
