module Accounting
  class SyncQuotationPayment
    def self.call(payment, actor: nil)
      new(payment, actor: actor).call
    end

    def initialize(payment, actor: nil)
      @payment = payment
      @quotation = payment.quotation
      @actor = actor
    end

    def call
      return destroy_linked_records if payment.destroyed?

      if payment.refunded?
        sync_refund
      elsif payment.recorded?
        sync_income
      elsif payment.failed?
        sync_failed_invoice
      else
        destroy_linked_records
      end
    end

    private

    attr_reader :payment, :quotation, :actor

    def sync_income
      margin_cents = quotation.margin_income_cents_for_payment(payment)
      transaction = AccountingTransaction.find_or_initialize_by(quotation_payment: payment)

      if margin_cents.positive?
        transaction.assign_attributes(
          transaction_type: :income,
          amount_cents: margin_cents,
          transaction_date: payment.paid_on || Date.current,
          description: "Removlo margin for #{quotation.reference}",
          vendor_payee: quotation.customer.email,
          payment_method: payment.payment_method,
          reference: payment.reference,
          quotation: quotation,
          user: quotation.customer,
          accounting_category: income_category
        )
        transaction.save!
      else
        AccountingTransaction.where(quotation_payment: payment).destroy_all
      end

      invoice = CustomerInvoice.find_or_initialize_by(quotation_payment: payment)
      invoice.assign_attributes(
        invoice_type: :standard,
        customer: quotation.customer,
        quotation: quotation,
        amount_cents: payment.amount_cents,
        status: :paid,
        issued_on: payment.paid_on || Date.current,
        settled_on: payment.paid_on || Date.current,
        notes: payment.notes
      )
      was_new = invoice.new_record?
      invoice.save!

      notify_customer_invoice(invoice, was_new)
      transaction
    end

    def sync_refund
      margin_cents = recognized_margin_cents_for_refund
      transaction = AccountingTransaction.find_or_initialize_by(quotation_payment: payment)

      if margin_cents.positive?
        transaction.assign_attributes(
          transaction_type: :refund,
          amount_cents: margin_cents,
          transaction_date: payment.paid_on || Date.current,
          description: "Margin refund for #{quotation.reference}",
          vendor_payee: quotation.customer.email,
          payment_method: payment.payment_method,
          reference: payment.reference,
          quotation: quotation,
          user: quotation.customer,
          accounting_category: refund_category
        )
        transaction.save!
      else
        AccountingTransaction.where(quotation_payment: payment).destroy_all
      end

      invoice = CustomerInvoice.find_by(quotation_payment: payment)
      if invoice.present?
        should_notify = !invoice.refunded?
        invoice.update!(
          invoice_type: :refund,
          status: :refunded,
          settled_on: Date.current,
          notes: refund_notes(invoice.notes)
        )
        notify_refund_invoice(invoice) if should_notify
      else
        refund_invoice = CustomerInvoice.create!(
          invoice_type: :refund,
          customer: quotation.customer,
          quotation: quotation,
          quotation_payment: payment,
          amount_cents: payment.amount_cents,
          status: :refunded,
          issued_on: Date.current,
          settled_on: Date.current,
          notes: "Refund for #{quotation.reference}"
        )
        notify_refund_invoice(refund_invoice)
      end

      transaction
    end

    def sync_failed_invoice
      AccountingTransaction.where(quotation_payment: payment).destroy_all

      invoice = CustomerInvoice.find_or_initialize_by(quotation_payment: payment)
      invoice.assign_attributes(
        invoice_type: :standard,
        customer: quotation.customer,
        quotation: quotation,
        amount_cents: payment.amount_cents,
        status: :failed,
        issued_on: Date.current,
        settled_on: nil,
        notes: [payment.notes, "Stripe payment failed or was cancelled for #{quotation.reference}"].compact.join(" — ")
      )
      was_new = invoice.new_record?
      invoice.save!
      notify_failed_invoice(invoice) if was_new
      invoice
    end

    def destroy_linked_records
      AccountingTransaction.where(quotation_payment: payment).destroy_all
      CustomerInvoice.where(quotation_payment: payment).destroy_all
    end

    def income_category
      AccountingCategory.default_for(:income) || AccountingCategory.find_by!(slug: "moving-services")
    end

    def refund_category
      AccountingCategory.default_for(:refund) || AccountingCategory.find_by!(slug: "refunds")
    end

    def notify_customer_invoice(invoice, was_new)
      return unless was_new

      ::ActivityNotifier.call(
        recipients: invoice.customer,
        event_type: "accounting.invoice",
        title: "Invoice #{invoice.invoice_number}",
        body: "Your invoice for #{money(invoice.amount_cents)} is ready.",
        url: Rails.application.routes.url_helpers.customer_invoice_path(invoice),
        actor: actor,
        notifiable: invoice
      )
    end

    def notify_refund_invoice(invoice)
      ::ActivityNotifier.call(
        recipients: invoice.customer,
        event_type: "accounting.refund",
        title: "Refund invoice #{invoice.invoice_number}",
        body: "A refund of #{money(invoice.amount_cents)} has been issued.",
        url: Rails.application.routes.url_helpers.customer_invoice_path(invoice),
        actor: actor,
        notifiable: invoice
      )
    end

    def notify_failed_invoice(invoice)
      ::ActivityNotifier.call(
        recipients: invoice.customer,
        event_type: "accounting.invoice_failed",
        title: "Payment attempt invoice #{invoice.invoice_number}",
        body: "A payment attempt for #{money(invoice.amount_cents)} was not completed. You can try again from your quotation.",
        url: Rails.application.routes.url_helpers.customer_invoice_path(invoice),
        actor: actor,
        notifiable: invoice
      )
    end

    def money(cents)
      format("£%.2f", cents.to_i / 100.0)
    end

    def refund_notes(existing_notes)
      refund_note = "Refund for #{quotation.reference}"
      notes = existing_notes.to_s.split(" — ").reject(&:blank?)
      notes << refund_note unless notes.include?(refund_note)
      notes.join(" — ")
    end

    def recognized_margin_cents_for_refund
      existing_income = AccountingTransaction.income.find_by(quotation_payment: payment)
      return existing_income.amount_cents if existing_income.present?

      quotation.margin_income_cents_for_payment(payment)
    end
  end
end
