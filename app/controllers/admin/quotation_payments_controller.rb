module Admin
  class QuotationPaymentsController < BaseController
    before_action :set_quotation
    before_action :set_payment, only: %i[update destroy]

    def create
      @quotation.quotation_payments.create!(payment_params)
      notify_customer("Payment recorded", "A payment was recorded on #{@quotation.reference}.")
      redirect_to admin_quotation_path(@quotation), notice: "Payment recorded."
    rescue ActiveRecord::RecordInvalid => e
      redirect_to admin_quotation_path(@quotation), alert: e.record.errors.full_messages.to_sentence
    end

    def update
      @payment.update!(payment_params)
      notify_customer("Payment updated", "A payment was updated on #{@quotation.reference}.")
      redirect_to admin_quotation_path(@quotation), notice: "Payment updated."
    rescue ActiveRecord::RecordInvalid => e
      redirect_to admin_quotation_path(@quotation), alert: e.record.errors.full_messages.to_sentence
    end

    def destroy
      @payment.destroy
      notify_customer("Payment removed", "A payment was removed from #{@quotation.reference}.")
      redirect_to admin_quotation_path(@quotation), notice: "Payment removed."
    end

    private

    def set_quotation
      @quotation = Quotation.find(params[:quotation_id])
    end

    def set_payment
      @payment = @quotation.quotation_payments.find(params[:id])
    end

    def payment_params
      attrs = params.require(:quotation_payment).permit(:amount, :payment_method, :status, :paid_on, :reference, :notes)
      value = attrs.delete(:amount)
      attrs[:amount_cents] = (BigDecimal(value.presence || "0") * 100).to_i
      attrs
    end

    def notify_customer(title, body)
      ::ActivityNotifier.call(
        recipients: @quotation.customer,
        event_type: "quotation.payment",
        title: title,
        body: body,
        url: quotation_path(@quotation),
        actor: current_user,
        notifiable: @quotation
      )
    end
  end
end
