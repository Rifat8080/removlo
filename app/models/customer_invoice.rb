class CustomerInvoice < ApplicationRecord
  INVOICE_TYPES = {
    standard: "standard",
    refund: "refund"
  }.freeze

  STATUSES = {
    draft: "draft",
    issued: "issued",
    paid: "paid",
    failed: "failed",
    refunded: "refunded",
    cancelled: "cancelled"
  }.freeze

  belongs_to :customer, class_name: "User"
  belongs_to :quotation, optional: true
  belongs_to :quotation_payment, optional: true

  enum :invoice_type, INVOICE_TYPES, default: :standard, validate: true
  enum :status, STATUSES, default: :issued, validate: true

  validates :invoice_number, presence: true, uniqueness: true
  validates :amount_cents, numericality: { greater_than: 0 }
  validates :issued_on, presence: true
  validates :quotation_payment_id, uniqueness: true, allow_nil: true

  before_validation :assign_invoice_number, on: :create

  scope :recent, -> { order(issued_on: :desc, created_at: :desc) }
  scope :for_customer, ->(user) { where(customer: user).recent }
  scope :unpaid, -> { where(status: %w[issued draft]) }

  def amount
    amount_cents.to_i / 100.0
  end

  private

  def assign_invoice_number
    return if invoice_number.present?

    prefix = refund? ? "RFD" : "INV"
    date_part = (issued_on || Date.current).strftime("%Y%m%d")
    sequence = self.class.where("invoice_number LIKE ?", "#{prefix}-#{date_part}-%").count + 1
    self.invoice_number = format("%s-%s-%03d", prefix, date_part, sequence)
  end
end
