class QuotationPayment < ApplicationRecord
  STATUSES = {
    recorded: "recorded",
    pending: "pending",
    failed: "failed",
    refunded: "refunded"
  }.freeze

  belongs_to :quotation

  enum :status, STATUSES, default: :recorded, validate: true

  validates :amount_cents, numericality: { greater_than: 0 }
  validates :payment_method, presence: true

  after_commit :sync_quotation_payment_status, on: %i[create update destroy]
  after_commit :sync_accounting_records, on: %i[create update destroy]

  def amount
    amount_cents.to_i / 100.0
  end

  private

  def sync_quotation_payment_status
    quotation.sync_payment_status! unless quotation.destroyed?
  end

  def sync_accounting_records
    return if quotation.destroyed?

    Accounting::SyncQuotationPayment.call(self)
  end
end
