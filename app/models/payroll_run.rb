class PayrollRun < ApplicationRecord
  STATUSES = {
    draft: "draft",
    finalized: "finalized",
    paid: "paid"
  }.freeze

  belongs_to :created_by, class_name: "User", optional: true
  has_many :payslips, dependent: :destroy

  enum :status, STATUSES, default: :draft, validate: true

  validates :period_start, :period_end, presence: true
  validate :period_end_after_start

  scope :recent, -> { order(period_end: :desc, created_at: :desc) }

  after_commit :sync_accounting_records, if: :saved_change_to_status?

  def total_net_pay_cents
    payslips.sum(:net_pay_cents)
  end

  def total_net_pay
    total_net_pay_cents / 100.0
  end

  def period_label
    "#{period_start.strftime('%d %b %Y')} – #{period_end.strftime('%d %b %Y')}"
  end

  private

  def sync_accounting_records
    return unless paid?

    Accounting::SyncPayrollRun.call(self)
  end

  def period_end_after_start
    return if period_start.blank? || period_end.blank?
    return if period_end >= period_start

    errors.add(:period_end, "must be on or after period start")
  end
end
