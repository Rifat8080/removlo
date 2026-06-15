class Ability
  include CanCan::Ability

  def initialize(user, cart_session_token: nil)
    user ||= User.new

    can :read, BlogPost
    can :read, Product
    can :read, ProductCategory
    can :create, Quotation
    can :create, MaterialOrder

    return guest_rules(cart_session_token) unless user.persisted?

    can :read, :dashboard
    can :manage, Cart, user_id: user.id
    can :manage, Notification, user_id: user.id
    can :manage, WebPushSubscription, user_id: user.id
    can :read, Conversation do |conversation|
      conversation.participant_for(user).present?
    end
    can :create, Message do |message|
      message.conversation&.participant_for(user).present?
    end
    can :create_internal, Message if user.operator?
    can :read, Message do |message|
      message.conversation&.participant_for(user).present? && (!message.internal_only? || user.operator?)
    end
    can :download, ActiveStorage::Attachment do |attachment|
      message = attachment.record
      message.is_a?(Message) && can?(:read, message)
    end

    case user.role
    when "admin"
      admin_rules(user)
    when "staff"
      staff_rules(user)
    when "driver"
      driver_rules(user)
    when "customer"
      customer_rules(user)
    end
  end

  private

  def guest_rules(cart_session_token)
    can :read, :public_job
    can :manage, Cart, session_token: cart_session_token if cart_session_token.present?
    can :read, MaterialOrder do |order|
      cart_session_token.present? && order.cart&.session_token == cart_session_token
    end
  end

  def admin_rules(user)
    can :manage, :all
    cannot :destroy, User, id: user.id
  end

  def staff_rules(user)
    can :access, :operations
    can :read, [
      AccountingCategory,
      AccountingTransaction,
      BlogPost,
      DriverOffer,
      DriverProfile,
      DriverWalletEntry,
      PayrollRun,
      Product,
      ProductCategory,
      Quotation,
      QuotationDocument,
      QuotationItem,
      QuotationNote,
      QuotationPayment,
      QuotationStatusEvent,
      User
    ]
    can [:read, :pdf], CustomerInvoice, customer_id: user.id
    can [:read, :pdf], MaterialOrder, customer_id: user.id
    can [:read, :pdf], Payslip, employee_id: user.id
    can [:create, :update], Quotation
    can :transition, Quotation
    can [:create, :update, :destroy], [QuotationDocument, QuotationItem, QuotationNote]
    can [:index, :select], DriverOffer
    can [:read, :create, :update], Conversation
    can [:create, :create_internal], Message
    cannot [:approve_negotiated_price, :reject_negotiated_price], Quotation
    cannot [:approve_cash, :create, :update, :destroy], QuotationPayment
    cannot [:approve, :payout], DriverWalletEntry
    cannot [:create, :update, :destroy], [AccountingCategory, AccountingTransaction, BlogPost, PayrollRun, Product, ProductCategory, User]
  end

  def driver_rules(user)
    can :access, :driver_workspace
    can :create, Conversation do |conversation|
      quotation = conversation.conversationable
      quotation.is_a?(Quotation) &&
        quotation.assigned_driver_id == user.id &&
        quotation.customer_details_releasable?
    end
    can :read, DriverProfile, user_id: user.id
    can :manage, DriverAvailability, driver_id: user.id
    can :read, DriverWalletEntry, driver_id: user.id
    can [:connect_stripe, :withdraw], DriverWalletEntry, driver_id: user.id
    can :read, Payslip, employee_id: user.id
    can :read, Quotation do |quotation|
      quotation.awaiting_driver_offers? || quotation.assigned_driver_id == user.id
    end
    can [:start, :complete, :cancel_assignment], Quotation, assigned_driver_id: user.id
    can [:create, :update, :accept_negotiation], DriverOffer, driver_id: user.id
    can :create, DriverLocation do |location|
      quotation = location.quotation
      quotation&.assigned_driver_id == user.id && quotation.tracking_active?
    end
  end

  def customer_rules(user)
    can [:read, :pdf], CustomerInvoice, customer_id: user.id
    can [:read, :pdf], MaterialOrder, customer_id: user.id
    can :create, MaterialOrder
    can :read, Quotation, customer_id: user.id
    can [:edit, :update], Quotation do |quotation|
      quotation.customer_id == user.id && quotation.customer_editable?
    end
    can [:accept, :reject, :request_changes, :deposit_checkout, :balance_checkout, :cash_payment_request, :cash_balance_request], Quotation, customer_id: user.id
    can :create, Conversation
    can :manage, Cart, user_id: user.id
  end
end
