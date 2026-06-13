module Driver
  class WalletsController < BaseController
    MIN_WITHDRAWAL_CENTS = 5_000

    def show
      load_wallet
    end

    def withdraw
      amount_cents = withdrawal_amount_cents
      available_cents = current_user.wallet_available_cents

      if amount_cents < MIN_WITHDRAWAL_CENTS
        redirect_to driver_wallet_path, alert: "Withdrawal amount must be at least #{helpers.money_from_cents(MIN_WITHDRAWAL_CENTS)}."
        return
      end

      if amount_cents > available_cents
        redirect_to driver_wallet_path, alert: "Withdrawal amount cannot exceed your available balance of #{helpers.money_from_cents(available_cents)}."
        return
      end

      entry = current_user.driver_wallet_entries.create!(
        entry_type: :withdrawal_request,
        status: :pending,
        amount_cents: -amount_cents,
        reference: "WITHDRAW-#{SecureRandom.hex(4).upcase}",
        notes: "Driver requested withdrawal of #{helpers.money_from_cents(amount_cents)}"
      )
      notify_admins(entry, amount_cents)
      redirect_to driver_wallet_path, notice: "Withdrawal request for #{helpers.money_from_cents(amount_cents)} was sent for approval."
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

    def notify_admins(entry, amount_cents)
      ::ActivityNotifier.call(
        recipients: User.where(role: "admin"),
        event_type: "driver_wallet.withdrawal_requested",
        title: "Driver withdrawal requested",
        body: "#{current_user.email} requested #{helpers.money_from_cents(amount_cents)}.",
        url: admin_wallet_payouts_path,
        actor: current_user,
        notifiable: entry
      )
    end
  end
end
