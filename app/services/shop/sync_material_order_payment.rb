module Shop
  class SyncMaterialOrderPayment
    include Rails.application.routes.url_helpers
    def self.call(order)
      new(order).call
    end

    def initialize(order)
      @order = order
    end

    def call
      return if order.payment_status != "paid"

      sync_accounting
      notify_customer
      notify_admins
    end

    private

    attr_reader :order

    def sync_accounting
      category = AccountingCategory.find_by(slug: "packing-materials-sales") ||
                 AccountingCategory.default_for(:income)

      transaction = AccountingTransaction.find_or_initialize_by(reference: "MO-#{order.id}")
      transaction.assign_attributes(
        transaction_type: :income,
        amount_cents: order.total_cents,
        transaction_date: (order.paid_at || Time.current).to_date,
        description: "Material order #{order.order_number}",
        vendor_payee: order.customer_email,
        payment_method: "stripe",
        user: order.customer,
        accounting_category: category
      )
      transaction.save!
    end

    def notify_customer
      recipient = order.customer
      return if recipient.blank?

      ::ActivityNotifier.call(
        recipients: recipient,
        event_type: "shop.order.paid",
        title: "Order #{order.order_number} confirmed",
        body: "Your payment of #{money(order.total_cents)} was received.",
        url: material_order_path(order),
        notifiable: order
      )
    end

    def notify_admins
      admins = User.where(role: "admin")
      return if admins.none?

      ::ActivityNotifier.call(
        recipients: admins,
        event_type: "shop.order.paid",
        title: "New material order #{order.order_number}",
        body: "#{order.customer_email} paid #{money(order.total_cents)}.",
        url: admin_shop_material_order_path(order),
        notifiable: order
      )
    end

    def money(cents)
      format("£%.2f", cents.to_i / 100.0)
    end
  end
end
