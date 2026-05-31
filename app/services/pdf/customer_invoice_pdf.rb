require "prawn"
require "prawn/table"

module Pdf
  class CustomerInvoicePdf
    def initialize(invoice)
      @invoice = invoice
    end

    def render
      document = Prawn::Document.new(page_size: "A4", margin: 48)
      header(document)
      invoice_summary(document)
      quotation_details(document)
      notes(document)
      footer(document)
      document.render
    end

    private

    attr_reader :invoice

    def header(document)
      document.text "Removlo", size: 26, style: :bold, color: "1D4ED8"
      document.move_down 4
      document.text "Professional moving services", size: 10, color: "64748B"
      document.move_down 28

      title = invoice.refund? ? "Refund Invoice" : "Customer Invoice"
      document.text title, size: 22, style: :bold, color: "0F172A"
      document.text invoice.invoice_number, size: 12, color: "475569"
      document.move_down 20
    end

    def invoice_summary(document)
      rows = [
        ["Customer", invoice.customer.email],
        ["Invoice type", invoice.invoice_type.humanize],
        ["Status", invoice.status.humanize],
        ["Issued on", format_date(invoice.issued_on)],
        ["Settled on", format_date(invoice.settled_on)],
        ["Amount", money(invoice.amount_cents)]
      ]

      document.table(rows, cell_style: { borders: [], padding: [6, 4], size: 10 }) do
        column(0).font_style = :bold
        column(0).text_color = "475569"
        column(1).text_color = "0F172A"
      end
      document.move_down 18
    end

    def quotation_details(document)
      return if invoice.quotation.blank?

      quotation = invoice.quotation
      document.text "Move details", size: 14, style: :bold, color: "0F172A"
      document.move_down 8
      rows = [
        ["Quotation", quotation.reference],
        ["Pickup", [quotation.pickup_address, quotation.pickup_postcode].compact_blank.join(", ")],
        ["Delivery", [quotation.delivery_address, quotation.delivery_postcode].compact_blank.join(", ")],
        ["Move date", format_date(quotation.preferred_move_date)],
        ["Service", quotation.service_level.to_s.humanize]
      ]

      document.table(rows, cell_style: { borders: [], padding: [5, 4], size: 9 }) do
        column(0).font_style = :bold
        column(0).text_color = "475569"
      end
      document.move_down 18
    end

    def notes(document)
      return if invoice.notes.blank?

      document.text "Notes", size: 14, style: :bold, color: "0F172A"
      document.move_down 8
      document.text invoice.notes, size: 10, color: "334155"
      document.move_down 18
    end

    def footer(document)
      document.stroke_horizontal_rule
      document.move_down 10
      document.text "Generated on #{Time.current.strftime('%d %b %Y at %H:%M')}", size: 8, color: "94A3B8"
      document.text "Thank you for choosing Removlo.", size: 8, color: "94A3B8"
    end

    def money(cents)
      format("GBP %.2f", cents.to_i / 100.0)
    end

    def format_date(date)
      date&.strftime("%d %b %Y") || "-"
    end
  end
end
