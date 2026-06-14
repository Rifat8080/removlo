class QuotationsController < ApplicationController
  before_action :authenticate_user!, except: :create
  before_action :require_customer!, except: :create
  before_action :set_quotation, only: %i[show edit update accept reject request_changes]
  before_action :require_customer_editable!, only: %i[edit update]

  layout "dashboard"

  def index
    authorize! :read, Quotation
    @quotations = Quotation.for_customer(current_user)
  end

  def show
    if ::Quotations::ReconcileStripePayments.call(quotation: @quotation, actor: current_user)
      @quotation.reload
    end

    @negotiation_note = @quotation.quotation_notes.new(internal: false)
    @invoices = @quotation.customer_invoices.recent
    @workflow_step = @quotation.workflow_step_for_customer
    @job_chat_available = @quotation.customer_details_releasable? && @quotation.assigned_driver.present?
    @job_conversation = @quotation.job_conversation if @job_chat_available
    @job_chat_messages = @job_conversation&.messages&.visible_to_participants&.chronological || []
  end

  def edit
    authorize! :edit, @quotation
    build_blank_item
  end

  def new
    authorize! :create, Quotation
    @quotation = current_user.customer_quotations.new(
      status: :requested,
      move_size: "studio",
      service_level: "standard"
    )
    build_blank_item
  end

  def create
    customer = quotation_customer
    return unless customer

    @quotation = customer.customer_quotations.new(quotation_request_params)
    @quotation.status = :requested
    authorize! :create, @quotation

    if @quotation.save
      @quotation.quotation_status_events.create!(to_status: @quotation.status, user: current_user || customer, note: "Customer requested a quotation")
      ::Quotations::PostForDrivers.call(quotation: @quotation, actor: current_user || customer)
      notify_operators("New quotation request", "#{customer.email} requested a quotation.", @quotation)
      sign_in(customer) if current_user.blank?
      redirect_to quotation_path(@quotation), notice: "Your quotation request has been sent."
    elsif current_user.blank?
      redirect_to get_quotation_path, alert: @quotation.errors.full_messages.to_sentence
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    authorize! :update, @quotation
    previous_status = @quotation.status

    if @quotation.update(quotation_request_params)
      mark_customer_edit!(previous_status)
      notify_operators("Quotation request updated", "#{current_user.email} updated #{@quotation.reference}.", @quotation)
      redirect_to quotation_path(@quotation), notice: "Your quotation request has been updated."
    else
      build_blank_item
      render :edit, status: :unprocessable_entity
    end
  end

  def accept
    authorize! :accept, @quotation
    unless @quotation.quoted_price_cents.positive?
      redirect_to quotation_path(@quotation), alert: "A quote price must be set before acceptance."
      return
    end

    unless @quotation.deposit_cents.positive?
      redirect_to quotation_path(@quotation), alert: "A deposit amount must be set before you can accept this quote."
      return
    end

    if @quotation.deposit_cents.positive? && !@quotation.deposit_protected?
      redirect_to quotation_path(@quotation), alert: "Please pay the deposit to accept and secure this quote."
      return
    end

    accept_quotation_after_deposit!
    redirect_to quotation_path(@quotation), notice: "Quote accepted. Your booking is now secured."
  end

  def reject
    authorize! :reject, @quotation
    @quotation.transition_to!(:rejected, actor: current_user, note: "Customer rejected the quote")
    notify_operators("Quote rejected", "#{current_user.email} rejected #{@quotation.reference}.", @quotation)
    redirect_to quotation_path(@quotation), notice: "Quote rejected."
  end

  def request_changes
    authorize! :request_changes, @quotation
    note = params.dig(:quotation_note, :content).to_s.strip

    if note.blank?
      redirect_to quotation_path(@quotation), alert: "Please add a message for the negotiation."
      return
    end

    @quotation.quotation_notes.create!(user: current_user, content: note, internal: false)
    @quotation.transition_to!(:negotiating, actor: current_user, note: "Customer requested quote changes")
    notify_operators("Negotiation requested", "#{current_user.email} asked to negotiate #{@quotation.reference}.", @quotation)
    redirect_to quotation_path(@quotation), notice: "Your negotiation request has been sent."
  rescue ActiveRecord::RecordInvalid => e
    redirect_to quotation_path(@quotation), alert: e.record.errors.full_messages.to_sentence
  end

  private

  def accept_quotation_after_deposit!
    return if @quotation.accepted?

    @quotation.transition_to!(:accepted, actor: current_user, note: "Customer accepted the quote after deposit payment")
    notify_operators("Quote accepted", "#{current_user.email} accepted #{@quotation.reference}.", @quotation)
  end

  def set_quotation
    @quotation = Quotation.for_customer(current_user).find(params[:id])
    authorize! :read, @quotation
  end

  def quotation_request_params
    attrs = params.require(:quotation).permit(
      :move_size,
      :service_level,
      :preferred_move_date,
      :pickup_postcode,
      :delivery_postcode,
      :pickup_address,
      :delivery_address,
      :access_notes,
        :customer_notes,
        quotation_items_attributes: %i[id name quantity fragile notes _destroy]
    )

    attrs[:service_level] = attrs[:service_level].presence || "standard"
    attrs[:move_size] = attrs[:move_size].presence || "studio"
    attrs[:pickup_address] = attrs[:pickup_address].presence || fallback_address("Pickup", attrs[:pickup_postcode])
    attrs[:delivery_address] = attrs[:delivery_address].presence || fallback_address("Delivery", attrs[:delivery_postcode])
    attrs[:customer_notes] = attrs[:customer_notes].presence || "Submitted from the landing page 2-minute quotation form."
    attrs
  end

  def require_customer_editable!
    return if @quotation.customer_editable?

    redirect_to quotation_path(@quotation), alert: "This quotation can no longer be edited. Message the team if you need a change."
  end

  def build_blank_item
    @quotation.quotation_items.build if @quotation.quotation_items.empty?
  end

  def mark_customer_edit!(previous_status)
    return unless previous_status.in?(%w[quoted negotiating])

    @quotation.transition_to!(:negotiating, actor: current_user, note: "Customer edited quotation request details")
  rescue ActiveRecord::RecordInvalid, ArgumentError
    @quotation.quotation_status_events.create!(
      from_status: previous_status,
      to_status: @quotation.status,
      user: current_user,
      note: "Customer edited quotation request details"
    )
  end

  def require_customer!
    return if current_user.customer?

    redirect_to admin_quotations_path, alert: "Operators manage quotations from the operations area."
  end

  def quotation_customer
    return current_user if current_user&.customer?

    if current_user&.operator?
      redirect_to admin_quotations_path, alert: "Operators should create quotations from the operations area."
      return
    end

    email = params.dig(:quotation, :customer_email).to_s.strip.downcase

    if email.blank?
      redirect_to get_quotation_path, alert: "Please add your email so we can create your quotation request."
      return
    end

    existing_user = User.find_by(email: email)
    if existing_user
      redirect_to new_user_session_path, alert: "Please sign in to request a quotation with this email."
      return
    end

    User.create!(email: email, role: :customer, password: SecureRandom.urlsafe_base64(24))
  rescue ActiveRecord::RecordInvalid => e
    redirect_to get_quotation_path, alert: e.record.errors.full_messages.to_sentence
    nil
  end

  def fallback_address(label, postcode)
    [label, postcode.presence].compact.join(" postcode: ")
  end

  def notify_operators(title, body, quotation)
    ::ActivityNotifier.call(
      recipients: User.operators,
      event_type: "quotation.customer_activity",
      title: title,
      body: body,
      url: admin_quotation_path(quotation),
      actor: current_user,
      notifiable: quotation
    )
  end
end
