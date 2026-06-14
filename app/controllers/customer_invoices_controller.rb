class CustomerInvoicesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_invoice, only: %i[show pdf]

  layout "dashboard"

  def index
    authorize! :read, CustomerInvoice
    @invoices = current_user.customer_invoices.includes(:quotation)
  end

  def show
    authorize! :read, @invoice
  end

  def pdf
    authorize! :pdf, @invoice
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
end
