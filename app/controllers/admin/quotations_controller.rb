module Admin
  class QuotationsController < BaseController
    before_action :set_quotation, only: %i[show edit update destroy transition]

    def index
      @quotations = Quotation.includes(:customer, :assigned_staff, :assigned_driver).recent
      @status_counts = Quotation.group(:status).count
    end

    def show
      @item = @quotation.quotation_items.new
      @note = @quotation.quotation_notes.new(internal: true)
      @payment = @quotation.quotation_payments.new(paid_on: Date.current)
      @document = @quotation.quotation_documents.new
      @broadcast = @quotation.quotation_broadcasts.new(minimum_rating: 4.5, require_available: true)
      @comparison = DriverOffers::Score.call(offers: @quotation.driver_offers.active.for_comparison)
      @inventory_estimate = @quotation.inventory_estimate || @quotation.build_inventory_estimate
    end

    def new
      @quotation = Quotation.new(defaults)
    end

    def edit
    end

    def create
      @quotation = Quotation.new(quotation_params)
      @quotation.created_by = current_user

      if @quotation.save
        @quotation.quotation_status_events.create!(to_status: @quotation.status, user: current_user, note: "Quotation created")
        notify_customer("Quotation created", "Your quotation #{@quotation.reference} has been created.", @quotation)
        redirect_to admin_quotation_path(@quotation), notice: "Quotation was created successfully."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def update
      previous_driver = @quotation.assigned_driver

      if @quotation.update(quotation_params)
        notify_quote_participants("Quotation updated", "#{@quotation.reference} was updated by #{current_user.email}.", @quotation)
        notify_driver_assignment(previous_driver) if @quotation.saved_change_to_assigned_driver_id?
        redirect_to admin_quotation_path(@quotation), notice: "Quotation was updated successfully."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @quotation.destroy
      redirect_to admin_quotations_path, notice: "Quotation was deleted successfully."
    end

    def transition
      @quotation.transition_to!(params.require(:status), actor: current_user, note: params[:note])
      if @quotation.completed?
        DriverWallet::RecordJobEarning.call(quotation: @quotation)
        @quotation.update!(awaiting_driver_offers: false)
      end
      notify_quote_participants("Quotation status changed", "#{@quotation.reference} is now #{@quotation.status.humanize}.", @quotation)
      redirect_to admin_quotation_path(@quotation), notice: "Quotation status updated."
    rescue ActiveRecord::RecordInvalid, ArgumentError => e
      redirect_to admin_quotation_path(@quotation), alert: e.message
    end

    private

    def set_quotation
      @quotation = Quotation.find(params[:id])
    end

    def quotation_params
      attrs = params.require(:quotation).permit(
        :customer_id,
        :assigned_staff_id,
        :assigned_driver_id,
        :status,
        :move_size,
        :service_level,
        :preferred_move_date,
        :scheduled_at,
        :pickup_postcode,
        :delivery_postcode,
        :pickup_address,
        :delivery_address,
        :access_notes,
        :customer_notes,
        :quoted_price,
        :deposit,
        :driver_cost,
        :markup_percentage,
        :vehicle_required,
        :expected_duration_hours,
        :property_type,
        :customer_details_released
      )

      normalize_money(attrs, :quoted_price, :quoted_price_cents)
      normalize_money(attrs, :deposit, :deposit_cents)
      normalize_money(attrs, :driver_cost, :driver_cost_cents)
      if attrs[:driver_cost_cents].to_i.positive? && attrs[:markup_percentage].present?
        markup = BigDecimal(attrs[:markup_percentage].to_s)
        customer_price = (attrs[:driver_cost_cents] * (1 + markup / 100)).round
        attrs[:quoted_price_cents] = customer_price
        attrs[:admin_margin_cents] = customer_price - attrs[:driver_cost_cents]
      end
      attrs
    end

    def defaults
      {
        move_size: "studio",
        service_level: "standard",
        status: "draft",
        payment_status: "unpaid"
      }
    end

    def normalize_money(attrs, source, target)
      return unless attrs.key?(source)

      value = attrs.delete(source)
      attrs[target] = (BigDecimal(value.presence || "0") * 100).to_i
    end

    def notify_customer(title, body, quotation)
      ::ActivityNotifier.call(
        recipients: quotation.customer,
        event_type: "quotation.admin_activity",
        title: title,
        body: body,
        url: quotation_path(quotation),
        actor: current_user,
        notifiable: quotation
      )
    end

    def notify_quote_participants(title, body, quotation)
      ::ActivityNotifier.call(
        recipients: quotation.customer,
        event_type: "quotation.admin_activity",
        title: title,
        body: body,
        url: quotation_path(quotation),
        actor: current_user,
        notifiable: quotation
      )
      ::ActivityNotifier.call(
        recipients: quotation.assigned_staff,
        event_type: "quotation.admin_activity",
        title: title,
        body: body,
        url: admin_quotation_path(quotation),
        actor: current_user,
        notifiable: quotation
      )
      ::ActivityNotifier.call(
        recipients: quotation.assigned_driver,
        event_type: "quotation.driver_activity",
        title: title,
        body: body,
        url: driver_job_path(quotation),
        actor: current_user,
        notifiable: quotation
      )
    end

    def notify_driver_assignment(previous_driver)
      return if @quotation.assigned_driver.blank?

      body =
        if previous_driver.present?
          "Driver changed from #{previous_driver.email} to #{@quotation.assigned_driver.email} for #{@quotation.reference}."
        else
          "You have been assigned to #{@quotation.reference}."
        end

      ::ActivityNotifier.call(
        recipients: @quotation.assigned_driver,
        event_type: "quotation.driver_assigned",
        title: "Job assigned",
        body: body,
        url: driver_job_path(@quotation),
        actor: current_user,
        notifiable: @quotation
      )
    end
  end
end
