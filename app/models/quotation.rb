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
  VEHICLE_TYPES = DriverProfile::VEHICLE_TYPES
  PROPERTY_TYPES = %w[studio flat house office storage].freeze

  belongs_to :customer, class_name: "User"
  belongs_to :created_by, class_name: "User", optional: true
  belongs_to :assigned_staff, class_name: "User", optional: true
  belongs_to :assigned_driver, class_name: "User", optional: true
  belongs_to :selected_driver_offer, class_name: "DriverOffer", optional: true

  has_many :quotation_items, dependent: :destroy
  has_many :quotation_notes, dependent: :destroy
  has_many :quotation_payments, dependent: :destroy
  has_many :quotation_documents, dependent: :destroy
  has_many :quotation_status_events, dependent: :destroy
  has_many :accounting_transactions, dependent: :nullify
  has_many :customer_invoices, dependent: :nullify
  has_many :driver_offers, dependent: :destroy
  has_many :quotation_broadcasts, dependent: :destroy
  has_one :inventory_estimate, class_name: "QuotationInventoryEstimate", dependent: :destroy
  has_one :job_conversation, class_name: "Conversation", as: :conversationable, dependent: :destroy

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
  scope :new_leads, -> { where(status: "requested") }
  scope :pending_quotes, -> { where(status: %w[draft quoted negotiating]) }
  scope :awaiting_driver, -> { where(awaiting_driver_offers: true) }
  scope :booked_jobs, -> { where(status: %w[accepted scheduled in_progress]) }

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

  def deposit_protected?
    deposit_paid? || paid?
  end

  def customer_details_releasable?
    deposit_protected? || customer_details_released?
  end

  def driver_visible_pickup_address
    return pickup_address if customer_details_releasable?

    pickup_postcode.presence || "Collection area provided after booking confirmed"
  end

  def driver_visible_delivery_address
    return delivery_address if customer_details_releasable?

    delivery_postcode.presence || "Delivery area provided after booking confirmed"
  end

  def driver_visible_collection_label
    extract_city_or_postcode(pickup_postcode, pickup_address, "Collection")
  end

  def driver_visible_delivery_label
    extract_city_or_postcode(delivery_postcode, delivery_address, "Delivery")
  end

  def apply_markup_from_driver_cost!(driver_cost_cents:, markup_percentage: nil)
    cost = driver_cost_cents.to_i
    markup = markup_percentage || self.markup_percentage
    customer_price = (cost * (1 + markup.to_f / 100.0)).round

    update!(
      driver_cost_cents: cost,
      markup_percentage: markup,
      admin_margin_cents: customer_price - cost,
      quoted_price_cents: customer_price
    )
  end

  def workflow_step_for_customer
    return :track_booking if deposit_protected? || scheduled? || in_progress? || completed?
    return :pay_deposit if accepted?
    return :receive_quote if quoted? || negotiating?
    :request_quote
  end

  private

  def extract_city_or_postcode(postcode, address, fallback)
    return postcode if postcode.present?

    address.to_s.split(",").last&.strip.presence || fallback
  end

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
    return if assigned_driver.blank?

    unless confirmed_for_driver_assignment?
      errors.add(:assigned_driver, "can only be assigned after the quotation is accepted")
      return
    end

    return if deposit_protected? || customer_details_released?

    errors.add(:assigned_driver, "can only be assigned after deposit or full payment is received")
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
