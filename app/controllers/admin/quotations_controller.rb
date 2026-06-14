module Admin
  class QuotationsController < BaseController
    before_action :set_quotation, only: %i[show edit update destroy transition approve_negotiated_price reject_negotiated_price]
    before_action :require_admin_for_quotation_mutation!, only: %i[edit destroy]
    before_action :require_admin!, only: %i[approve_negotiated_price reject_negotiated_price]

    def index
      authorize! :read, Quotation
      @quotations = Quotation.includes(:customer, :assigned_staff, :assigned_driver).recent
      @status_counts = Quotation.group(:status).count
    end

    def show
      authorize! :read, @quotation
      @item = @quotation.quotation_items.new
      @note = @quotation.quotation_notes.new(internal: true)
      @payment = @quotation.quotation_payments.new(paid_on: Date.current)
      @document = @quotation.quotation_documents.new
      @comparison = DriverOffers::Score.call(offers: @quotation.driver_offers.active.for_comparison)
    end

    def new
      @quotation = Quotation.new(defaults)
      authorize! :create, @quotation
    end

    def edit
      authorize! :edit, @quotation
    end

    def create
      @quotation = Quotation.new(quotation_params)
      @quotation.created_by = current_user
      authorize! :create, @quotation

      if @quotation.save
        @quotation.quotation_status_events.create!(to_status: @quotation.status, user: current_user, note: "Quotation created")
        ::Quotations::PostForDrivers.call(quotation: @quotation, actor: current_user)
        notify_customer("Quotation created", "Your quotation #{@quotation.reference} has been created.", @quotation)
        redirect_to admin_quotation_path(@quotation), notice: "Quotation was created successfully."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def update
      authorize! :update, @quotation
      previous_driver = @quotation.assigned_driver
      attrs = current_user.admin? ? quotation_params : staff_operational_quotation_params
      proposed_price_cents = staff_negotiated_price_cents unless current_user.admin?

      unless current_user.admin? || attrs.present? || proposed_price_cents.present?
        redirect_to admin_quotation_path(@quotation), alert: "Only admins can edit quotation details."
        return
      end

      if @quotation.update(attrs)
        if proposed_price_cents.present?
          @quotation.propose_negotiated_price!(price_cents: proposed_price_cents, actor: current_user)
          notify_negotiated_price_request
        end
        notify_quote_participants("Quotation updated", "#{@quotation.reference} was updated by #{current_user.email}.", @quotation) unless proposed_price_cents.present? && attrs.blank?
        if @quotation.saved_change_to_assigned_driver_id?
          @quotation.update!(awaiting_driver_offers: false) if @quotation.assigned_driver.present?
          @quotation.auto_schedule_after_driver_assignment!(actor: current_user)
          notify_driver_assignment(previous_driver)
        end
        notice = proposed_price_cents.present? ? "Negotiated price sent to admins for approval." : "Quotation was updated successfully."
        redirect_to admin_quotation_path(@quotation), notice: notice
      else
        current_user.admin? ? render(:edit, status: :unprocessable_entity) : redirect_to(admin_quotation_path(@quotation), alert: @quotation.errors.full_messages.to_sentence)
      end
    rescue ArgumentError => e
      redirect_to admin_quotation_path(@quotation), alert: "Quotation could not be updated: #{e.message}"
    end

    def destroy
      authorize! :destroy, @quotation
      @quotation.destroy
      redirect_to admin_quotations_path, notice: "Quotation was deleted successfully."
    end

    def transition
      authorize! :transition, @quotation
      if staff_restricted_transition?(params.require(:status))
        redirect_to admin_quotation_path(@quotation), alert: "Drivers start and complete assigned jobs. Only admins can perform that action from admin."
        return
      end

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

    def approve_negotiated_price
      authorize! :approve_negotiated_price, @quotation
      @quotation.approve_negotiated_price!(actor: current_user)
      @quotation.request_driver_offer_renegotiation!
      notify_negotiated_price_approved
      notify_drivers_negotiated_bid_request
      redirect_to admin_quotation_path(@quotation), notice: "Negotiated price approved. The quote can now be sent to the customer."
    rescue ArgumentError, ActiveRecord::RecordInvalid => e
      redirect_to admin_quotation_path(@quotation), alert: e.message
    end

    def reject_negotiated_price
      authorize! :reject_negotiated_price, @quotation
      @quotation.reject_negotiated_price!(actor: current_user)
      notify_negotiated_price_rejected
      redirect_to admin_quotation_path(@quotation), notice: "Negotiated price was marked as not approved."
    rescue ArgumentError, ActiveRecord::RecordInvalid => e
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
      normalize_margin_pricing(attrs)
      attrs
    end

    def staff_operational_quotation_params
      attrs = params.require(:quotation).permit(
        :assigned_driver_id,
        :customer_details_released
      )
      attrs
    end

    def staff_negotiated_price_cents
      value = params.dig(:quotation, :negotiated_price)
      return if value.blank?

      cents = (BigDecimal(value) * 100).to_i
      raise ArgumentError, "Negotiated price must be greater than zero." unless cents.positive?

      cents
    rescue ArgumentError
      raise ArgumentError, "Negotiated price must be a valid amount."
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

    def normalize_margin_pricing(attrs)
      driver_cost_cents =
        if attrs.key?(:driver_cost_cents)
          attrs[:driver_cost_cents].to_i
        else
          @quotation&.driver_cost_cents.to_i
        end
      markup_percentage = attrs[:markup_percentage].presence || @quotation&.markup_percentage

      if driver_cost_cents.positive? && markup_percentage.present? && (attrs.key?(:driver_cost_cents) || attrs.key?(:markup_percentage))
        markup = BigDecimal(markup_percentage.to_s)
        customer_price = (driver_cost_cents * (1 + markup / 100)).round
        attrs[:driver_cost_cents] = driver_cost_cents
        attrs[:markup_percentage] = markup
        attrs[:quoted_price_cents] = customer_price
        attrs[:admin_margin_cents] = customer_price - driver_cost_cents
        return
      end

      return unless attrs.key?(:quoted_price_cents) && driver_cost_cents.positive?

      attrs[:admin_margin_cents] = [attrs[:quoted_price_cents].to_i - driver_cost_cents, 0].max
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

    def notify_negotiated_price_request
      ::ActivityNotifier.call(
        recipients: User.where(role: "admin"),
        event_type: "quotation.negotiated_price_pending",
        title: "Negotiated price needs approval",
        body: "#{current_user.email} proposed #{helpers.money_from_cents(@quotation.pending_quoted_price_cents)} for #{@quotation.reference}.",
        url: admin_quotation_path(@quotation),
        actor: current_user,
        notifiable: @quotation
      )
      @quotation.quotation_notes.create!(
        user: current_user,
        internal: true,
        content: "Proposed negotiated customer price: #{helpers.money_from_cents(@quotation.pending_quoted_price_cents)}. Awaiting admin approval before sending."
      )
    end

    def notify_negotiated_price_approved
      ::ActivityNotifier.call(
        recipients: @quotation.negotiated_price_requested_by,
        event_type: "quotation.negotiated_price_approved",
        title: "Negotiated price approved",
        body: "#{@quotation.reference} is approved at #{helpers.money_from_cents(@quotation.quoted_price_cents)} and ready to send.",
        url: admin_quotation_path(@quotation),
        actor: current_user,
        notifiable: @quotation
      )
      ::ActivityNotifier.call(
        recipients: @quotation.customer,
        event_type: "quotation.negotiation_accepted",
        title: "Negotiation accepted",
        body: "Your negotiated price for #{@quotation.reference} was accepted. The updated quotation price is #{helpers.money_from_cents(@quotation.quoted_price_cents)}.",
        url: quotation_path(@quotation),
        actor: current_user,
        notifiable: @quotation
      )
      @quotation.quotation_notes.create!(
        user: current_user,
        internal: true,
        content: "Approved negotiated customer price: #{helpers.money_from_cents(@quotation.quoted_price_cents)}. Ready to send to the customer."
      )
    end

    def notify_negotiated_price_rejected
      ::ActivityNotifier.call(
        recipients: @quotation.negotiated_price_requested_by,
        event_type: "quotation.negotiated_price_rejected",
        title: "Negotiated price not approved",
        body: "#{@quotation.reference} was not approved at #{helpers.money_from_cents(@quotation.pending_quoted_price_cents)}.",
        url: admin_quotation_path(@quotation),
        actor: current_user,
        notifiable: @quotation
      )
      ::ActivityNotifier.call(
        recipients: @quotation.customer,
        event_type: "quotation.negotiation_rejected",
        title: "Negotiation update",
        body: "Your negotiated price request for #{@quotation.reference} could not be approved at this stage. The team will continue from the current quote price of #{helpers.money_from_cents(@quotation.quoted_price_cents)}.",
        url: quotation_path(@quotation),
        actor: current_user,
        notifiable: @quotation
      )
      @quotation.quotation_notes.create!(
        user: current_user,
        internal: true,
        content: "Negotiated customer price not approved: #{helpers.money_from_cents(@quotation.pending_quoted_price_cents)}. Customer was notified."
      )
    end

    def notify_drivers_negotiated_bid_request
      offers = @quotation.driver_offers.where(renegotiation_status: "pending").includes(:driver)
      offers.find_each do |offer|
        ::ActivityNotifier.call(
          recipients: offer.driver,
          event_type: "driver_offer.negotiation_requested",
          title: "Negotiated job price available",
          body: "#{@quotation.reference} has a negotiated price of #{helpers.money_from_cents(offer.renegotiation_price_cents)}. Accept it to update your bid.",
          url: driver_job_path(@quotation),
          actor: current_user,
          notifiable: offer
        )
      end

      @quotation.quotation_notes.create!(
        user: current_user,
        internal: true,
        content: "Sent negotiated price #{helpers.money_from_cents(@quotation.quoted_price_cents)} to #{offers.count} driver bid(s) for acceptance."
      )
    end

    def require_admin_for_quotation_mutation!
      return if current_user&.admin?

      redirect_to(@quotation ? admin_quotation_path(@quotation) : admin_quotations_path, alert: "Only admins can edit quotations.")
    end

    def staff_restricted_transition?(status)
      current_user.staff? && Quotation::STAFF_RESTRICTED_TRANSITION_STATUSES.include?(status.to_s)
    end
  end
end
