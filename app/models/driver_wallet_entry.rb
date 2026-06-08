class DriverWalletEntry < ApplicationRecord
  ENTRY_TYPES = {
    job_earning: "job_earning",
    payout: "payout",
    adjustment: "adjustment"
  }.freeze

  STATUSES = {
    pending: "pending",
    available: "available",
    withdrawn: "withdrawn",
    cancelled: "cancelled"
  }.freeze

  belongs_to :driver, class_name: "User"
  belongs_to :quotation, optional: true
  belongs_to :approved_by, class_name: "User", optional: true

  enum :entry_type, ENTRY_TYPES, validate: true
  enum :status, STATUSES, default: :pending, validate: true

  validates :amount_cents, numericality: { other_than: 0 }
  validate :driver_must_be_driver

  scope :recent, -> { order(created_at: :desc) }
  scope :credits, -> { where("amount_cents > 0") }
  scope :debits, -> { where("amount_cents < 0") }

  def amount
    amount_cents.to_i / 100.0
  end

  def approve!(actor:)
    unless approvable?
      errors.add(:base, "Only pending credit entries can be approved")
      raise ActiveRecord::RecordInvalid, self
    end

    update!(status: :available, approved_by: actor, approved_at: Time.current)
  end

  def mark_withdrawn!
    unless payable?
      errors.add(:base, "Only available credit entries can be paid out")
      raise ActiveRecord::RecordInvalid, self
    end

    update!(status: :withdrawn)
  end

  def approvable?
    pending? && amount_cents.positive?
  end

  def payable?
    available? && amount_cents.positive?
  end

  private

  def driver_must_be_driver
    return if driver.blank? || driver.driver?

    errors.add(:driver, "must have the driver role")
  end
end
