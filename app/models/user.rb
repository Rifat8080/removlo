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

  before_validation :set_default_role, on: :create

  scope :customers, -> { where(role: "customer").order(:email) }
  scope :operators, -> { where(role: %w[admin staff]).order(:email) }
  scope :drivers, -> { where(role: "driver").order(:email) }

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
