class DriverOffer < ApplicationRecord
  STATUSES = {
    submitted: "submitted",
    withdrawn: "withdrawn",
    selected: "selected",
    rejected: "rejected"
  }.freeze

  belongs_to :quotation
  belongs_to :driver, class_name: "User"

  validates :amount_cents, numericality: { greater_than: 0 }
  validates :renegotiation_price_cents, numericality: { greater_than: 0 }, allow_nil: true
  validates :renegotiation_status, inclusion: { in: %w[none pending accepted] }
  validates :driver_id, uniqueness: { scope: :quotation_id }
  validate :driver_must_be_driver
  validate :quotation_accepting_driver_offers, on: :create

  enum :status, STATUSES, default: :submitted, validate: true

  scope :recent, -> { order(created_at: :desc) }
  scope :active, -> { where(status: %w[submitted selected]) }
  scope :for_comparison, -> { includes(driver: :driver_profile).order(amount_cents: :asc) }

  def amount
    amount_cents.to_i / 100.0
  end

  def pending_renegotiation?
    renegotiation_status == "pending" && renegotiation_price_cents.present?
  end

  def accepted_renegotiation?
    renegotiation_status == "accepted" && renegotiation_price_cents.present?
  end

  def request_renegotiation!(price_cents:)
    update!(
      renegotiation_price_cents: price_cents,
      renegotiation_status: "pending",
      renegotiation_requested_at: Time.current,
      renegotiation_responded_at: nil,
      status: :submitted,
      selected_by_admin: false
    )
  end

  def accept_renegotiation!
    raise ArgumentError, "There is no negotiated bid request to accept." unless pending_renegotiation?

    update!(
      amount_cents: renegotiation_price_cents,
      renegotiation_status: "accepted",
      renegotiation_responded_at: Time.current,
      status: :submitted,
      selected_by_admin: false
    )
  end

  def driver_rating
    driver.driver_profile&.rating || 0
  end

  def driver_jobs_count
    driver.driver_profile&.completed_jobs_count || driver.driver_jobs.completed.count
  end

  private

  def driver_must_be_driver
    return if driver.blank? || driver.driver?

    errors.add(:driver, "must have the driver role")
  end

  def quotation_accepting_driver_offers
    return if quotation&.awaiting_driver_offers?

    errors.add(:quotation, "is not accepting driver offers")
  end
end
