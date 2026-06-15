module Driver
  class WalletsController < BaseController
    MIN_WITHDRAWAL_CENTS = 5_000

    def show
      authorize! :read, DriverWalletEntry
      load_wallet
      @driver_profile = current_user.driver_profile
    end

    def connect_stripe
      authorize! :connect_stripe, wallet_authorization_subject
      if ENV["STRIPE_SECRET_KEY"].blank?
        redirect_to driver_wallet_path, alert: "Stripe payouts are not configured yet. Contact support."
        return
      end

      onboarding_url = ::Stripe::ConnectOnboarding.call(
        driver: current_user,
        return_url: stripe_return_driver_wallet_url,
        refresh_url: connect_stripe_driver_wallet_url
      )
      redirect_to onboarding_url, allow_other_host: true
    rescue ::Stripe::ConnectOnboarding::Error, ::Stripe::StripeError => e
      redirect_to driver_wallet_path, alert: "Could not start Stripe onboarding: #{e.message}"
    end

    def stripe_return
      authorize! :connect_stripe, wallet_authorization_subject

      profile = current_user.driver_profile
      ::Stripe::SyncDriverAccount.call(profile) if profile.present?

      if profile&.stripe_payouts_ready?
        redirect_to driver_wallet_path, notice: "Stripe payout account connected. You can now request withdrawals."
      else
        redirect_to driver_wallet_path, alert: "Stripe onboarding is incomplete. Finish setup to request withdrawals."
      end
    end

    def withdraw
      authorize! :withdraw, wallet_authorization_subject
      payout_method = withdrawal_payout_method
      profile = current_user.driver_profile || DriverProfile.ensure_for!(current_user)
      if payout_method == "stripe" && !profile.stripe_payouts_ready?
        redirect_to driver_wallet_path, alert: "Connect and complete Stripe payout setup before requesting a Stripe withdrawal."
        return
      end

      amount_cents = withdrawal_amount_cents
      entry = nil

      if amount_cents < MIN_WITHDRAWAL_CENTS
        redirect_to driver_wallet_path, alert: "Withdrawal amount must be at least #{helpers.money_from_cents(MIN_WITHDRAWAL_CENTS)}."
        return
      end

      current_user.with_lock do
        available_cents = current_user.wallet_available_cents

        if amount_cents > available_cents
          redirect_to driver_wallet_path, alert: "Withdrawal amount cannot exceed your available balance of #{helpers.money_from_cents(available_cents)}."
          return
        end

        entry = current_user.driver_wallet_entries.create!(
          entry_type: :withdrawal_request,
          status: :pending,
          amount_cents: -amount_cents,
          payout_method: payout_method,
          reference: "WITHDRAW-#{SecureRandom.hex(4).upcase}",
          notes: "Driver requested #{payout_method} withdrawal of #{helpers.money_from_cents(amount_cents)}"
        )
      end
      notify_admins(entry, amount_cents)
      redirect_to driver_wallet_path, notice: "#{payout_method.humanize} withdrawal request for #{helpers.money_from_cents(amount_cents)} was sent for approval."
    rescue ArgumentError
      redirect_to driver_wallet_path, alert: "Enter a valid withdrawal amount."
    end

    private

    def load_wallet
      @entries = current_user.driver_wallet_entries.recent
      @pending_cents = current_user.wallet_pending_cents
      @available_cents = current_user.wallet_available_cents
      @total_cents = current_user.wallet_balance_cents
      @requested_withdrawal_cents = current_user.wallet_requested_withdrawal_cents
    end

    def withdrawal_amount_cents
      value = params.dig(:withdrawal, :amount).to_s
      raise ArgumentError if value.blank?

      (BigDecimal(value) * 100).to_i
    rescue ArgumentError
      raise ArgumentError
    end

    def withdrawal_payout_method
      method = params.dig(:withdrawal, :payout_method).presence || "stripe"
      return method if method.in?(DriverWalletEntry::PAYOUT_METHODS)

      raise ArgumentError
    end

    def notify_admins(entry, amount_cents)
      ::ActivityNotifier.call(
        recipients: User.where(role: "admin"),
        event_type: "driver_wallet.withdrawal_requested",
        title: "Driver withdrawal requested",
        body: "#{current_user.email} requested #{helpers.money_from_cents(amount_cents)} by #{entry.payout_method}.",
        url: admin_wallet_payouts_path,
        actor: current_user,
        notifiable: entry
      )
    end

    def wallet_authorization_subject
      DriverWalletEntry.new(driver: current_user)
    end
  end
end
