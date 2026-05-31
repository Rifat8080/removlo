class Quotation < ApplicationRecord
  STATUSES = {
    requested: "requested",
    draft: "draft",
    quoted: "quoted",
    negotiating: "negotiating",
    accepted: "accepted",
    rejected: "rejected",
    scheduled: "scheduled",
    in_progress: "in_progress",
    completed: "completed",
    cancelled: "cancelled"
  }.freeze

  PAYMENT_STATUSES = {
    unpaid: "unpaid",
    deposit_paid: "deposit_paid",
    paid: "paid",
    refunded: "refunded"
  }.freeze

  MOVE_SIZES = %w[studio one_bed two_bed three_bed four_plus office].freeze
  SERVICE_LEVELS = %w[standard packing storage full_service].freeze

  belongs_to :customer, class_name: "User"
  belongs_to :created_by, class_name: "User", optional: true
  belongs_to :assigned_staff, class_name: "User", optional: true
  belongs_to :assigned_driver, class_name: "User", optional: true

  has_many :quotation_items, dependent: :destroy
  has_many :quotation_notes, dependent: :destroy
  has_many :quotation_payments, dependent: :destroy
  has_many :quotation_documents, dependent: :destroy
  has_many :quotation_status_events, dependent: :destroy

  enum :status, STATUSES, default: :draft, validate: true
  enum :payment_status, PAYMENT_STATUSES, default: :unpaid, validate: true

  validates :reference, presence: true, uniqueness: true
  validates :pickup_address, :delivery_address, :move_size, :service_level, presence: true
  validates :move_size, inclusion: { in: MOVE_SIZES }
  validates :service_level, inclusion: { in: SERVICE_LEVELS }
  validates :quoted_price_cents, :deposit_cents, numericality: { greater_than_or_equal_to: 0 }
  validate :customer_must_be_customer
  validate :assigned_staff_must_be_operator
  validate :assigned_driver_must_be_driver
  validate :driver_assignment_requires_confirmed_quote

  before_validation :assign_reference, on: :create

  scope :recent, -> { order(created_at: :desc) }
  scope :for_customer, ->(user) { where(customer: user).recent }
  scope :for_driver, ->(user) { where(assigned_driver: user).recent }

  def quoted_price
    quoted_price_cents.to_i / 100.0
  end

  def deposit
    deposit_cents.to_i / 100.0
  end

  def transition_to!(next_status, actor:, note: nil)
    previous_status = status
    update!(status: next_status, **timestamp_for(next_status))
    quotation_status_events.create!(from_status: previous_status, to_status: next_status, user: actor, note: note)
  end

  def sync_payment_status!
    total_paid = quotation_payments.recorded.sum(:amount_cents)

    next_status =
      if total_paid <= 0
        :unpaid
      elsif quoted_price_cents.positive? && total_paid >= quoted_price_cents
        :paid
      elsif total_paid >= deposit_cents
        :deposit_paid
      else
        :unpaid
      end

    update_column(:payment_status, next_status)
  end

  def confirmed_for_driver_assignment?
    accepted? || scheduled? || in_progress? || completed?
  end

  private

  def assign_reference
    self.reference ||= loop do
      token = "Q-#{Time.current.strftime('%Y%m%d')}-#{SecureRandom.hex(3).upcase}"
      break token unless self.class.exists?(reference: token)
    end
  end

  def customer_must_be_customer
    errors.add(:customer, "must have the customer role") if customer && !customer.customer?
  end

  def assigned_staff_must_be_operator
    return if assigned_staff.blank? || assigned_staff.operator?

    errors.add(:assigned_staff, "must be an admin or staff user")
  end

  def assigned_driver_must_be_driver
    return if assigned_driver.blank? || assigned_driver.driver?

    errors.add(:assigned_driver, "must have the driver role")
  end

  def driver_assignment_requires_confirmed_quote
    return if assigned_driver.blank? || confirmed_for_driver_assignment?

    errors.add(:assigned_driver, "can only be assigned after the quotation is accepted")
  end

  def timestamp_for(next_status)
    case next_status.to_s
    when "quoted" then { quoted_at: Time.current }
    when "accepted" then { accepted_at: Time.current }
    when "completed" then { completed_at: Time.current }
    when "cancelled" then { cancelled_at: Time.current }
    else {}
    end
  end
end
