module Admin
  module Accounting
    class DashboardController < BaseController
      def index
        @summary = AccountingTransaction.summary_for
        @month_summary = AccountingTransaction.summary_for(
          start_date: Date.current.beginning_of_month,
          end_date: Date.current.end_of_month
        )
        @recent_transactions = AccountingTransaction.includes(:accounting_category, :user).recent.limit(8)
        @unpaid_invoices = CustomerInvoice.unpaid.includes(:customer, :quotation).limit(6)
        @recent_payslips = Payslip.includes(:employee, :payroll_run).recent.limit(6)
      end
    end
  end
end
