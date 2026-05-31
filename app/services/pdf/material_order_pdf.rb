require "prawn"
require "prawn/table"

module Pdf
  class MaterialOrderPdf
    def initialize(order)
      @order = order
    end

    def render
      document = Prawn::Document.new(page_size: "A4", margin: 48)
      document.text "Removlo", size: 26, style: :bold, color: "1D4ED8"
      document.text "Material order receipt", size: 22, style: :bold
      document.text order.order_number, size: 12, color: "475569"
      document.move_down 20

      rows = [
        ["Customer", order.customer_email],
        ["Status", order.status.humanize],
        ["Payment", order.payment_status.humanize],
        ["Fulfillment", order.fulfillment_type.humanize],
        ["Total", money(order.total_cents)]
      ]
      document.table(rows, cell_style: { borders: [], padding: [6, 4], size: 10 }) do
        column(0).font_style = :bold
      end
      document.move_down 16

      item_rows = [["Item", "Qty", "Unit", "Total"]] + order.material_order_items.map do |item|
        [item.product_name, item.quantity.to_s, money(item.unit_price_cents), money(item.line_total_cents)]
      end
      document.table(item_rows, width: document.bounds.width, cell_style: { padding: [6, 4], size: 9 }) do
        row(0).font_style = :bold
        column(1..3).align = :right
      end

      document.render
    end

    private

    attr_reader :order

    def money(cents)
      format("GBP %.2f", cents.to_i / 100.0)
    end
  end
end
