module Admin
  module Accounting
    class CustomerInvoicesController < BaseController
      before_action :set_invoice, only: %i[show edit update destroy pdf]

      def index
        authorize! :read, CustomerInvoice
        @invoices = CustomerInvoice.includes(:customer, :quotation).recent
        @invoices = @invoices.where(invoice_type: params[:type]) if params[:type].present?
        @invoices = @invoices.where(status: params[:status]) if params[:status].present?
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

      def new
        @invoice = CustomerInvoice.new(issued_on: Date.current, status: :issued)
        authorize! :create, @invoice
      end

      def edit
        authorize! :update, @invoice
      end

      def create
        @invoice = CustomerInvoice.new(invoice_params)
        authorize! :create, @invoice

        if @invoice.save
          notify_invoice(@invoice)
          redirect_to admin_accounting_customer_invoice_path(@invoice), notice: "Invoice created."
        else
          render :new, status: :unprocessable_entity
        end
      end

      def update
        authorize! :update, @invoice

        if @invoice.update(invoice_params)
          redirect_to admin_accounting_customer_invoice_path(@invoice), notice: "Invoice updated."
        else
          render :edit, status: :unprocessable_entity
        end
      end

      def destroy
        authorize! :destroy, @invoice

        if @invoice.quotation_payment_id.present?
          redirect_to admin_accounting_customer_invoices_path, alert: "Payment-linked invoices cannot be deleted manually."
          return
        end

        @invoice.destroy
        redirect_to admin_accounting_customer_invoices_path, notice: "Invoice deleted."
      end

      private

      def set_invoice
        @invoice = CustomerInvoice.find(params[:id])
      end

      def invoice_params
        attrs = params.require(:customer_invoice).permit(
          :invoice_type, :customer_id, :quotation_id, :status, :issued_on, :settled_on, :notes, :amount
        )
        parse_amount_param(attrs)
      end

      def notify_invoice(invoice)
        ::ActivityNotifier.call(
          recipients: invoice.customer,
          event_type: "accounting.invoice",
          title: "Invoice #{invoice.invoice_number}",
          body: "Your invoice for #{helpers.money_from_cents(invoice.amount_cents)} is ready.",
          url: customer_invoice_path(invoice),
          actor: current_user,
          notifiable: invoice
        )
      end
    end
  end
end
