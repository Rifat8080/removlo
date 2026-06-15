module Admin
  class QuotationPaymentsController < BaseController
    before_action :require_admin!
    before_action :set_quotation
    before_action :set_payment, only: %i[update destroy approve_cash]

    def create
      payment = @quotation.quotation_payments.new(payment_params)
      authorize! :create, payment

      payment.save!
      notify_customer("Payment recorded", "A payment was recorded on #{@quotation.reference}.")
      redirect_to admin_quotation_path(@quotation), notice: "Payment recorded."
    rescue ActiveRecord::RecordInvalid => e
      redirect_to admin_quotation_path(@quotation), alert: e.record.errors.full_messages.to_sentence
    end

    def update
      authorize! :update, @payment

      @payment.update!(payment_params)
      notify_customer("Payment updated", "A payment was updated on #{@quotation.reference}.")
      redirect_to admin_quotation_path(@quotation), notice: "Payment updated."
    rescue ActiveRecord::RecordInvalid => e
      redirect_to admin_quotation_path(@quotation), alert: e.record.errors.full_messages.to_sentence
    end

    def destroy
      authorize! :destroy, @payment

      @payment.destroy
      notify_customer("Payment removed", "A payment was removed from #{@quotation.reference}.")
      redirect_to admin_quotation_path(@quotation), notice: "Payment removed."
    end

    def approve_cash
      authorize! :approve_cash, @payment

      unless @payment.pending_cash?
        redirect_to admin_quotation_path(@quotation), alert: "Only pending cash payment requests can be approved."
        return
      end

      @payment.update!(
        status: :recorded,
        paid_on: Date.current,
        notes: [@payment.notes, "Cash payment approved by #{current_user.email}."].compact_blank.join(" ")
      )
      @quotation.reload
      accept_quotation_after_cash_payment! if @payment.cash_acceptance_request?
      notify_customer("Cash payment approved", "Your cash payment for #{@quotation.reference} was approved.")
      redirect_to admin_quotation_path(@quotation), notice: "Cash payment approved."
    rescue ActiveRecord::RecordInvalid, ArgumentError => e
      redirect_to admin_quotation_path(@quotation), alert: e.message
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

    def accept_quotation_after_cash_payment!
      return if @quotation.accepted?
      return unless @quotation.deposit_protected? || @quotation.paid?

      @quotation.transition_to!(:accepted, actor: current_user, note: "Admin approved customer cash payment")
      ::ActivityNotifier.call(
        recipients: User.operators.where.not(id: current_user.id),
        event_type: "quotation.customer_activity",
        title: "Quote accepted after cash approval",
        body: "#{@quotation.reference} was accepted after cash payment approval.",
        url: admin_quotation_path(@quotation),
        actor: current_user,
        notifiable: @quotation
      )
    end
  end
end
