require "prawn"
require "prawn/table"

module Pdf
  class PayslipPdf
    def initialize(payslip)
      @payslip = payslip
    end

    def render
      document = Prawn::Document.new(page_size: "A4", margin: 48)
      header(document)
      employee_details(document)
      earnings(document)
      notes(document)
      footer(document)
      document.render
    end

    private

    attr_reader :payslip

    def header(document)
      document.text "Removlo", size: 26, style: :bold, color: "1D4ED8"
      document.move_down 4
      document.text "Payslip", size: 22, style: :bold, color: "0F172A"
      document.text payroll_period_label, size: 12, color: "475569"
      document.move_down 24
    end

    def employee_details(document)
      rows = [
        ["Employee", payslip.employee.email],
        ["Role", payslip.employee_role.humanize],
        ["Payment date", format_date(payslip.payment_date)],
        ["Payroll status", payslip.payroll_run.status.humanize]
      ]

      document.table(rows, cell_style: { borders: [], padding: [6, 4], size: 10 }) do
        column(0).font_style = :bold
        column(0).text_color = "475569"
      end
      document.move_down 18
    end

    def earnings(document)
      document.text "Earnings and deductions", size: 14, style: :bold, color: "0F172A"
      document.move_down 8

      rows = [
        ["Base salary", money(payslip.base_salary_cents)],
        ["Bonus", money(payslip.bonus_cents)],
        ["Commission", money(payslip.commission_cents)],
        ["Deductions", "-#{money(payslip.deductions_cents)}"],
        ["Net pay", money(payslip.net_pay_cents)]
      ]

      document.table(rows, width: document.bounds.width, cell_style: { padding: [8, 6], size: 10 }) do
        row(0..3).borders = [:bottom]
        row(0..3).border_color = "E2E8F0"
        row(4).font_style = :bold
        row(4).background_color = "EEF2FF"
        row(4).text_color = "1D4ED8"
        column(1).align = :right
      end
      document.move_down 18
    end

    def notes(document)
      return if payslip.notes.blank?

      document.text "Notes", size: 14, style: :bold, color: "0F172A"
      document.move_down 8
      document.text payslip.notes, size: 10, color: "334155"
      document.move_down 18
    end

    def footer(document)
      document.stroke_horizontal_rule
      document.move_down 10
      document.text "Generated on #{Time.current.strftime('%d %b %Y at %H:%M')}", size: 8, color: "94A3B8"
      document.text "This payslip is generated from Removlo payroll records.", size: 8, color: "94A3B8"
    end

    def money(cents)
      format("GBP %.2f", cents.to_i / 100.0)
    end

    def payroll_period_label
      "#{format_date(payslip.payroll_run.period_start)} to #{format_date(payslip.payroll_run.period_end)}"
    end

    def format_date(date)
      date&.strftime("%d %b %Y") || "-"
    end
  end
end
