class PagesController < ApplicationController
  before_action :authenticate_user!, only: :dashboard

  layout :pages_layout

  def landing
  end

  def seo_landing
    @seo_page = SeoLandingPage.find!(params[:slug])
  end

  def services
  end

  def home_removals
    @service = service_page(:home_removals)
  end

  def office_removals
    @service = service_page(:office_removals)
  end

  def packing_services
    @service = service_page(:packing_services)
  end

  def storage_solutions
    @service = service_page(:storage_solutions)
  end

  def how_it_works
  end

  def about
  end

  def reviews
  end

  def contact
  end

  def get_quotation
  end

  def dashboard
    authorize! :read, :dashboard

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
      ["Contact support", "mailto:support@removlo.co.uk", "Ask the Removlo team"]
    ]
  end

  def load_driver_dashboard
    @dashboard_title = "Driver workspace"
    @dashboard_subtitle = "See assigned jobs, upcoming work, and payouts in one place."
    @primary_action = ["View my jobs", driver_jobs_path]

    @driver_jobs = Quotation.for_driver(current_user).includes(:customer).limit(6)
    active_jobs = current_user.driver_jobs.where(status: %w[accepted scheduled in_progress])
    completed_jobs = current_user.driver_jobs.where(status: "completed")

    @dashboard_stats = [
      ["Active jobs", active_jobs.count, "Accepted or in progress", "truck", "from-indigo-500 to-blue-500"],
      ["Completed jobs", completed_jobs.count, "Finished moves", "check", "from-emerald-500 to-teal-500"],
      ["Wallet balance", helpers.money_from_cents(current_user.wallet_balance_cents), "Earnings recorded", "invoice", "from-blue-500 to-cyan-500"],
      ["Unread alerts", current_user.unread_notifications_count, "Latest activity", "bell", "from-violet-500 to-fuchsia-500"]
    ]

    @quick_actions = [
      ["Open my jobs", driver_jobs_path, "Assigned moves"],
      ["Availability", driver_availabilities_path, "Set when you can work"],
      ["Wallet", driver_wallet_path, "Earnings and payouts"],
      ["Notifications", notifications_path, "Salary payment alerts and job updates"]
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
    @quick_actions.insert(2, ["Accounting dashboard", admin_accounting_root_path, "Income, expenses, salaries, and invoices"]) if current_user.admin?
  end

  def pages_layout
    action_name == "dashboard" ? "dashboard" : "landing"
  end

  def service_page(key)
    {
      home_removals: {
        title: "Home Removals",
        slug: "home-removals",
        icon: "home_removals_icon.svg",
        image: "home_removals_image.png",
        description: "Professional home moves for flats, houses, and family relocations across the UK.",
        features: ["Room-by-room planning", "Careful loading and protection", "Live move tracking", "Flexible packing add-ons"],
        highlights: ["Ideal for local and long-distance moves", "Transparent crew and vehicle allocation", "Insurance options explained upfront"]
      },
      office_removals: {
        title: "Office Removals",
        slug: "office-removals",
        icon: "office_removals_icon.svg",
        image: "office_removals_image.png",
        description: "Minimise downtime with planned office relocations, weekend moves, and IT-safe handling.",
        features: ["Out-of-hours scheduling", "Desk and equipment labelling", "Phased move planning", "Dedicated move coordinator"],
        highlights: ["Designed for minimal business disruption", "Suitable for SMEs and multi-site teams", "Clear timelines before move day"]
      },
      packing_services: {
        title: "Packing Services",
        slug: "packing-services",
        icon: "packing_services_icon.svg",
        image: "packing_services_image.png",
        description: "Full or partial packing with quality materials, fragile-item care, and inventory support.",
        features: ["Professional packing teams", "Fragile-only options", "Materials supplied on request", "Labelled boxes for easy unpacking"],
        highlights: ["Great for busy households and professionals", "Reduces damage risk on move day", "Can be combined with removals"]
      },
      storage_solutions: {
        title: "Storage Solutions",
        slug: "storage-solutions",
        icon: "storage_solutions_icon.svg",
        image: "storage_solutions_image.png",
        description: "Secure short or long-term storage while you stage, renovate, or coordinate your move.",
        features: ["Flexible storage terms", "Collection and redelivery options", "Inventory on request", "Climate-suitable handling guidance"],
        highlights: ["Bridge the gap between exchange dates", "Useful during renovations", "Works alongside Removlo removals"]
      }
    }[key]
  end
end
