class User < ApplicationRecord
  ROLES = {
    admin: "admin",
    staff: "staff",
    driver: "driver",
    customer: "customer"
  }.freeze

  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable,
         :timeoutable, :lockable

  enum :role, ROLES, default: :customer, validate: true

  has_many :customer_quotations, class_name: "Quotation", foreign_key: :customer_id, dependent: :restrict_with_error
  has_many :created_quotations, class_name: "Quotation", foreign_key: :created_by_id, dependent: :nullify
  has_many :assigned_quotations, class_name: "Quotation", foreign_key: :assigned_staff_id, dependent: :nullify
  has_many :driver_jobs, class_name: "Quotation", foreign_key: :assigned_driver_id, dependent: :nullify
  has_one :driver_profile, dependent: :destroy
  has_many :driver_offers, foreign_key: :driver_id, dependent: :destroy
  has_many :driver_availabilities, foreign_key: :driver_id, dependent: :destroy
  has_many :driver_wallet_entries, foreign_key: :driver_id, dependent: :destroy
  has_many :quotation_notes, dependent: :nullify
  has_many :quotation_status_events, dependent: :nullify
  has_many :notifications, dependent: :destroy
  has_many :web_push_subscriptions, dependent: :destroy
  has_many :blog_posts, foreign_key: :author_id, dependent: :restrict_with_error
  has_many :accounting_transactions, dependent: :nullify
  has_many :customer_invoices, foreign_key: :customer_id, dependent: :restrict_with_error
  has_many :payslips, foreign_key: :employee_id, dependent: :restrict_with_error
  has_many :created_payroll_runs, class_name: "PayrollRun", foreign_key: :created_by_id, dependent: :nullify
  has_many :carts, dependent: :destroy
  has_many :material_orders, foreign_key: :customer_id, dependent: :nullify
  has_many :conversation_participants, dependent: :destroy
  has_many :conversations, through: :conversation_participants
  has_many :messages, foreign_key: :sender_id, dependent: :nullify

  before_validation :set_default_role, on: :create
  after_create :ensure_driver_profile

  scope :customers, -> { where(role: "customer").order(:email) }
  scope :operators, -> { where(role: %w[admin staff]).order(:email) }
  scope :drivers, -> { where(role: "driver").order(:email) }
  scope :payroll_eligible, -> { where(role: %w[admin staff driver]).order(:email) }

  def operator?
    admin? || staff?
  end

  def unread_notifications_count
    notifications.unread.count
  end

  def display_name
    email.to_s.split("@").first.to_s.tr("._-", " ").squish.titleize.presence || email
  end

  def wallet_balance_cents
    driver_wallet_entries.job_earning.where(status: %w[pending available withdrawn]).sum(:amount_cents)
  end

  def wallet_pending_cents
    driver_wallet_entries.job_earning.where(status: "pending").sum(:amount_cents)
  end

  def wallet_available_cents
    available_earnings = driver_wallet_entries.job_earning.where(status: "available").sum(:amount_cents)
    reserved_withdrawals = driver_wallet_entries.withdrawal_request.where(status: %w[pending available withdrawn]).sum(:amount_cents).abs
    [available_earnings - reserved_withdrawals, 0].max
  end

  def wallet_requested_withdrawal_cents
    driver_wallet_entries.withdrawal_request.where(status: %w[pending available]).sum(:amount_cents).abs
  end

  private

  def set_default_role
    self.role ||= "customer"
  end

  def ensure_driver_profile
    DriverProfile.ensure_for!(self) if driver?
  end
end
