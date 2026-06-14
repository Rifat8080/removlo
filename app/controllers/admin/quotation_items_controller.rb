module Admin
  class QuotationItemsController < BaseController
    before_action :set_quotation
    before_action :set_item, only: %i[update destroy]

    def create
      item = @quotation.quotation_items.new(item_params)
      authorize! :create, item
      item.save!
      notify_customer("Inventory updated", "An item was added to #{@quotation.reference}.")
      redirect_to admin_quotation_path(@quotation), notice: "Inventory item added."
    rescue ActiveRecord::RecordInvalid => e
      redirect_to admin_quotation_path(@quotation), alert: e.record.errors.full_messages.to_sentence
    end

    def update
      authorize! :update, @item
      @item.update!(item_params)
      notify_customer("Inventory updated", "An item was updated on #{@quotation.reference}.")
      redirect_to admin_quotation_path(@quotation), notice: "Inventory item updated."
    rescue ActiveRecord::RecordInvalid => e
      redirect_to admin_quotation_path(@quotation), alert: e.record.errors.full_messages.to_sentence
    end

    def destroy
      authorize! :destroy, @item
      @item.destroy
      notify_customer("Inventory updated", "An item was removed from #{@quotation.reference}.")
      redirect_to admin_quotation_path(@quotation), notice: "Inventory item removed."
    end

    private

    def set_quotation
      @quotation = Quotation.find(params[:quotation_id])
    end

    def set_item
      @item = @quotation.quotation_items.find(params[:id])
    end

    def item_params
      params.require(:quotation_item).permit(:name, :quantity, :fragile, :notes)
    end

    def notify_customer(title, body)
      ::ActivityNotifier.call(
        recipients: @quotation.customer,
        event_type: "quotation.inventory",
        title: title,
        body: body,
        url: quotation_path(@quotation),
        actor: current_user,
        notifiable: @quotation
      )
    end
  end
end
