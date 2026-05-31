class MaterialOrder < ApplicationRecord
  FULFILLMENT_TYPES = { delivery: "delivery", collection: "collection" }.freeze

  STATUSES = {
    pending: "pending",
    paid: "paid",
    processing: "processing",
    ready_for_collection: "ready_for_collection",
    dispatched: "dispatched",
    delivered: "delivered",
    collected: "collected",
    cancelled: "cancelled",
    refunded: "refunded"
  }.freeze

  PAYMENT_STATUSES = {
    unpaid: "unpaid",
    paid: "paid",
    refunded: "refunded",
    failed: "failed"
  }.freeze

  DELIVERY_FEE_CENTS = 500

  belongs_to :cart, optional: true
  belongs_to :customer, class_name: "User", optional: true
  has_many :material_order_items, dependent: :destroy

  enum :fulfillment_type, FULFILLMENT_TYPES, default: :delivery, validate: true
  enum :status, STATUSES, default: :pending, validate: true, prefix: :order
  enum :payment_status, PAYMENT_STATUSES, default: :unpaid, validate: true, prefix: :payment

  validates :order_number, :customer_email, presence: true
  validates :order_number, uniqueness: true
  validates :subtotal_cents, :delivery_fee_cents, :total_cents, numericality: { greater_than_or_equal_to: 0 }
  validate :delivery_details_required

  before_validation :assign_order_number, on: :create
  before_validation :recalculate_totals

  scope :recent, -> { order(created_at: :desc) }
  scope :for_customer, ->(user) { where(customer: user).recent }
  scope :paid_orders, -> { where(payment_status: "paid") }

  def total
    total_cents.to_i / 100.0
  end

  def mark_paid!(stripe_payment_intent_id: nil)
    return if payment_paid?

    transaction do
      self.subtotal_cents = material_order_items.sum(&:line_total_cents)
      recalculate_totals
      update!(
        status: :paid,
        payment_status: :paid,
        paid_at: Time.current,
        stripe_payment_intent_id: stripe_payment_intent_id,
        subtotal_cents: subtotal_cents,
        delivery_fee_cents: delivery_fee_cents,
        total_cents: total_cents
      )
      reduce_stock!
      Shop::SyncMaterialOrderPayment.call(self)
    end
  end

  def reduce_stock!
    material_order_items.includes(:product).find_each do |item|
      next if item.product.blank?

      item.product.decrement!(:stock_quantity, item.quantity)
    end
  end

  private

  def assign_order_number
    return if order_number.present?

    date_part = Time.current.strftime("%Y%m%d")
    sequence = self.class.where("order_number LIKE ?", "MO-#{date_part}-%").count + 1
    self.order_number = format("MO-%s-%03d", date_part, sequence)
  end

  def recalculate_totals
    self.delivery_fee_cents = delivery? ? DELIVERY_FEE_CENTS : 0
    self.total_cents = subtotal_cents.to_i + delivery_fee_cents.to_i
  end

  def delivery_details_required
    return unless delivery?
    return if order_pending?

    %i[delivery_name delivery_address delivery_postcode].each do |field|
      errors.add(field, "can't be blank for delivery") if self[field].blank?
    end
  end
end
