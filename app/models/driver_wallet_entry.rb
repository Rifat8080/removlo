class DriverWalletEntry < ApplicationRecord
  ENTRY_TYPES = {
    job_earning: "job_earning",
    withdrawal_request: "withdrawal_request",
    payout: "payout",
    adjustment: "adjustment"
  }.freeze

  STATUSES = {
    pending: "pending",
    available: "available",
    withdrawn: "withdrawn",
    cancelled: "cancelled"
  }.freeze
  PAYOUT_METHODS = %w[stripe cash].freeze

  belongs_to :driver, class_name: "User"
  belongs_to :quotation, optional: true
  belongs_to :approved_by, class_name: "User", optional: true

  enum :entry_type, ENTRY_TYPES, validate: true
  enum :status, STATUSES, default: :pending, validate: true

  before_validation :set_default_payout_method

  validates :amount_cents, numericality: { other_than: 0 }
  validates :payout_method, inclusion: { in: PAYOUT_METHODS }, allow_nil: true
  validate :driver_must_be_driver
  validate :withdrawal_request_must_be_debit
  validate :withdrawal_request_must_have_payout_method

  scope :recent, -> { order(created_at: :desc) }
  scope :credits, -> { where("amount_cents > 0") }
  scope :debits, -> { where("amount_cents < 0") }

  def amount
    amount_cents.to_i / 100.0
  end

  def approve!(actor:)
    unless approvable?
      errors.add(:base, "Only pending earnings or withdrawal requests can be approved")
      raise ActiveRecord::RecordInvalid, self
    end

    update!(status: :available, approved_by: actor, approved_at: Time.current)
  end

  def mark_withdrawn!
    unless payable?
      errors.add(:base, "Only available earnings or approved withdrawal requests can be paid out")
      raise ActiveRecord::RecordInvalid, self
    end

    update!(status: :withdrawn)
  end

  def mark_transfer_failed!(message:)
    update!(
      status: :available,
      stripe_transfer_status: "failed",
      stripe_transfer_error: message
    )
  end

  def mark_transfer_reversed!(message: nil)
    update!(
      status: :available,
      stripe_transfer_status: "reversed",
      stripe_transfer_error: message
    )
  end

  def approvable?
    pending? && (amount_cents.positive? || withdrawal_request?)
  end

  def payable?
    available? && withdrawal_request?
  end

  def stripe_payout?
    payout_method.blank? || payout_method == "stripe"
  end

  def cash_payout?
    payout_method == "cash"
  end

  private

  def set_default_payout_method
    self.payout_method ||= "stripe" if withdrawal_request?
  end

  def driver_must_be_driver
    return if driver.blank? || driver.driver?

    errors.add(:driver, "must have the driver role")
  end

  def withdrawal_request_must_be_debit
    return unless withdrawal_request?
    return if amount_cents.negative?

    errors.add(:amount_cents, "must be negative for withdrawal requests")
  end

  def withdrawal_request_must_have_payout_method
    return unless withdrawal_request?
    return if payout_method.in?(PAYOUT_METHODS)

    errors.add(:payout_method, "must be cash or stripe for withdrawal requests")
  end
end
