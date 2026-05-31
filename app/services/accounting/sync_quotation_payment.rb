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
      else
        destroy_linked_records
      end
    end

    private

    attr_reader :payment, :quotation, :actor

    def sync_income
      transaction = AccountingTransaction.find_or_initialize_by(quotation_payment: payment)
      transaction.assign_attributes(
        transaction_type: :income,
        amount_cents: payment.amount_cents,
        transaction_date: payment.paid_on || Date.current,
        description: "Payment for #{quotation.reference}",
        vendor_payee: quotation.customer.email,
        payment_method: payment.payment_method,
        reference: payment.reference,
        quotation: quotation,
        user: quotation.customer,
        accounting_category: income_category
      )
      transaction.save!

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
      transaction = AccountingTransaction.find_or_initialize_by(quotation_payment: payment)
      transaction.assign_attributes(
        transaction_type: :refund,
        amount_cents: payment.amount_cents,
        transaction_date: payment.paid_on || Date.current,
        description: "Refund for #{quotation.reference}",
        vendor_payee: quotation.customer.email,
        payment_method: payment.payment_method,
        reference: payment.reference,
        quotation: quotation,
        user: quotation.customer,
        accounting_category: refund_category
      )
      transaction.save!

      invoice = CustomerInvoice.find_by(quotation_payment: payment)
      if invoice.present?
        invoice.update!(
          invoice_type: :refund,
          status: :refunded,
          settled_on: Date.current,
          notes: [invoice.notes, "Refund for #{quotation.reference}"].compact.join(" — ")
        )
        notify_refund_invoice(invoice)
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

    def money(cents)
      format("£%.2f", cents.to_i / 100.0)
    end
  end
end
