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
         :recoverable, :rememberable, :validatable

  enum :role, ROLES, default: :customer, validate: true

  has_many :customer_quotations, class_name: "Quotation", foreign_key: :customer_id, dependent: :restrict_with_error
  has_many :created_quotations, class_name: "Quotation", foreign_key: :created_by_id, dependent: :nullify
  has_many :assigned_quotations, class_name: "Quotation", foreign_key: :assigned_staff_id, dependent: :nullify
  has_many :driver_jobs, class_name: "Quotation", foreign_key: :assigned_driver_id, dependent: :nullify
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

  before_validation :set_default_role, on: :create

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

  private

  def set_default_role
    self.role ||= "customer"
  end
end
