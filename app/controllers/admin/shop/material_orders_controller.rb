module Admin
  module Shop
    class MaterialOrdersController < BaseController
      before_action :set_order, only: %i[show update transition pdf]

      def index
        @orders = MaterialOrder.includes(:customer, :material_order_items).recent
        @orders = @orders.where(status: params[:status]) if params[:status].present?
        @orders = @orders.where(payment_status: params[:payment_status]) if params[:payment_status].present?
        @orders = @orders.where(fulfillment_type: params[:fulfillment_type]) if params[:fulfillment_type].present?
      end

      def show
      end

      def update
        if @order.update(order_params)
          Shop::NotifyOrderStatus.call(@order, previous_status: @order.status_before_last_save) if @order.saved_change_to_status?
          redirect_to admin_shop_material_order_path(@order), notice: "Order updated."
        else
          render :show, status: :unprocessable_entity
        end
      end

      def transition
        next_status = params[:status]
        if MaterialOrder::STATUSES.key?(next_status.to_sym)
          previous = @order.status
          @order.update!(status: next_status)
          Shop::NotifyOrderStatus.call(@order, previous_status: previous)
          redirect_to admin_shop_material_order_path(@order), notice: "Order status updated."
        else
          redirect_to admin_shop_material_order_path(@order), alert: "Invalid status."
        end
      end

      def pdf
        send_data(
          Pdf::MaterialOrderPdf.new(@order).render,
          filename: "#{@order.order_number.parameterize}.pdf",
          type: "application/pdf",
          disposition: "attachment"
        )
      end

      private

      def set_order
        @order = MaterialOrder.includes(:material_order_items, :customer).find(params[:id])
      end

      def order_params
        params.require(:material_order).permit(:admin_notes, :status)
      end
    end
  end
end
