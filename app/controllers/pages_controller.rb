class PagesController < ApplicationController
  before_action :authenticate_user!, only: :dashboard

  layout :pages_layout

  def landing
  end

  def dashboard
    @recent_notifications = current_user.notifications.recent.limit(5)

    if current_user.customer?
      load_customer_dashboard
    elsif current_user.driver?
      load_driver_dashboard
    else
      load_operator_dashboard
    end
  end

  private

  def load_customer_dashboard
    @dashboard_title = "Your moving hub"
    @dashboard_subtitle = "Track quotations, invoices, and messages without searching around."
    @primary_action = ["Request a quote", new_quotation_path]

    @customer_quotations = Quotation.for_customer(current_user).includes(:assigned_staff, :assigned_driver).limit(6)
    active_quotes = current_user.customer_quotations.where.not(status: %w[rejected completed cancelled])
    booked_moves = current_user.customer_quotations.where(status: %w[accepted scheduled in_progress])
    invoices = current_user.customer_invoices

    @dashboard_stats = [
      ["Active quotes", active_quotes.count, "Quotes still in progress", "doc", "from-indigo-500 to-blue-500"],
      ["Booked moves", booked_moves.count, "Accepted or scheduled", "truck", "from-blue-500 to-cyan-500"],
      ["Open invoices", invoices.unpaid.count, "Need attention", "invoice", "from-amber-500 to-orange-500"],
      ["Unread alerts", current_user.unread_notifications_count, "Latest activity", "bell", "from-violet-500 to-fuchsia-500"]
    ]

    @quick_actions = [
      ["Request a new quote", new_quotation_path, "Start a detailed request"],
      ["View my quotations", quotations_path, "Review prices and status"],
      ["Download invoices", customer_invoices_path, "Payments and refunds"],
      ["Contact support", "mailto:hello@removlo.co.uk", "Ask the Removlo team"]
    ]
  end

  def load_driver_dashboard
    @dashboard_title = "Driver workspace"
    @dashboard_subtitle = "See assigned jobs, upcoming work, and payroll in one place."
    @primary_action = ["View my jobs", driver_jobs_path]

    @driver_jobs = Quotation.for_driver(current_user).includes(:customer).limit(6)
    active_jobs = current_user.driver_jobs.where(status: %w[accepted scheduled in_progress])
    completed_jobs = current_user.driver_jobs.where(status: "completed")

    @dashboard_stats = [
      ["Active jobs", active_jobs.count, "Accepted or in progress", "truck", "from-indigo-500 to-blue-500"],
      ["Completed jobs", completed_jobs.count, "Finished moves", "check", "from-emerald-500 to-teal-500"],
      ["Payslips", current_user.payslips.count, "Payroll records", "invoice", "from-blue-500 to-cyan-500"],
      ["Unread alerts", current_user.unread_notifications_count, "Latest activity", "bell", "from-violet-500 to-fuchsia-500"]
    ]

    @quick_actions = [
      ["Open my jobs", driver_jobs_path, "Assigned moves"],
      ["Availability", driver_availabilities_path, "Set when you can work"],
      ["Wallet", driver_wallet_path, "Earnings and payouts"],
      ["View payslips", payslips_path, "Salary and commission records"]
    ]
  end

  def load_operator_dashboard
    @dashboard_title = current_user.admin? ? "Business overview" : "Operations overview"
    @dashboard_subtitle = "The most important work, finance, and customer activity at a glance."
    @primary_action = ["New quote", new_admin_quotation_path]

    @operations_quotations = Quotation.includes(:customer, :assigned_staff, :assigned_driver).recent.limit(6)
    @dashboard_stats = [
      ["New requests", Quotation.requested.count, "Waiting for review", "doc", "from-indigo-500 to-blue-500"],
      ["Negotiations", Quotation.negotiating.count, "Customer changes", "chat", "from-violet-500 to-fuchsia-500"],
      ["Active moves", Quotation.where(status: %w[accepted scheduled in_progress]).count, "Confirmed work", "truck", "from-blue-500 to-cyan-500"],
      ["Completed", Quotation.completed.where(completed_at: Date.current.beginning_of_month..).count, "This month", "check", "from-emerald-500 to-teal-500"]
    ]

    if current_user.admin?
      @accounting_summary = AccountingTransaction.summary_for(
        start_date: Date.current.beginning_of_month,
        end_date: Date.current.end_of_month
      )
      @open_invoices_count = CustomerInvoice.unpaid.count
      @team_count = User.payroll_eligible.count
    end

    @quick_actions = [
      ["Control panel", admin_root_path, "Lead queue and marketplace"],
      ["Create quotation", new_admin_quotation_path, "Build a quote for a customer"],
      ["Manage quotations", admin_quotations_path, "Requests, negotiations, jobs"],
      ["Driver performance", admin_driver_performances_path, "Ratings and revenue"]
    ]
    @quick_actions.insert(2, ["Accounting dashboard", admin_accounting_root_path, "Profit, invoices, payroll"]) if current_user.admin?
  end

  def pages_layout
    action_name == "dashboard" ? "dashboard" : "landing"
  end
end
