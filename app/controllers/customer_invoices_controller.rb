class CustomerInvoicesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_invoice, only: %i[show pdf]

  layout "dashboard"

  def index
    @invoices = current_user.customer_invoices.includes(:quotation)
  end

  def show
    authorize_invoice!
  end

  def pdf
    authorize_invoice!
    send_data(
      Pdf::CustomerInvoicePdf.new(@invoice).render,
      filename: "#{@invoice.invoice_number.parameterize}.pdf",
      type: "application/pdf",
      disposition: "attachment"
    )
  end

  private

  def set_invoice
    @invoice = CustomerInvoice.find(params[:id])
  end

  def authorize_invoice!
    return if @invoice.customer_id == current_user.id

    redirect_to customer_invoices_path, alert: "You are not authorized to view this invoice."
  end
end
