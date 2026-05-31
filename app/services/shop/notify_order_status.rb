module Shop
  class NotifyOrderStatus
    include Rails.application.routes.url_helpers
    MESSAGES = {
      "processing" => "Your order is being prepared.",
      "ready_for_collection" => "Your order is ready for collection.",
      "dispatched" => "Your order has been dispatched for delivery.",
      "delivered" => "Your order has been delivered.",
      "collected" => "Your order has been collected.",
      "cancelled" => "Your order was cancelled.",
      "refunded" => "Your order was refunded."
    }.freeze

    def self.call(order, previous_status:)
      new(order, previous_status).call
    end

    def initialize(order, previous_status)
      @order = order
      @previous_status = previous_status
    end

    def call
      return if order.status == previous_status
      return if order.customer.blank?

      body = MESSAGES[order.status]
      return if body.blank?

      ::ActivityNotifier.call(
        recipients: order.customer,
        event_type: "shop.order.status",
        title: "Order #{order.order_number} update",
        body: body,
        url: material_order_path(order),
        notifiable: order
      )
    end

    private

    attr_reader :order, :previous_status
  end
end
