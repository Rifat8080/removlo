module Stripe
  class DriverTransfer
    class Error < StandardError; end

    def self.call(entry:, actor:)
      new(entry, actor: actor).call
    end

    def initialize(entry, actor:)
      @entry = entry
      @actor = actor
    end

    def call
      validate_entry!

      profile = DriverProfile.ensure_for!(entry.driver)
      raise Error, "Driver has not connected a Stripe payout account." if profile.stripe_account_id.blank?
      raise Error, "Driver Stripe payouts are not enabled yet." unless profile.stripe_payouts_ready?

      amount_cents = entry.amount_cents.abs
      ensure_available_balance!(amount_cents)

      transfer = Stripe::Transfer.create(
        amount: amount_cents,
        currency: "gbp",
        destination: profile.stripe_account_id,
        metadata: {
          driver_wallet_entry_id: entry.id,
          driver_id: entry.driver_id
        }
      )

      entry.update!(
        status: :withdrawn,
        stripe_transfer_id: transfer.id,
        stripe_transfer_status: transfer_status(transfer),
        stripe_transfer_error: nil,
        approved_by: actor,
        approved_at: Time.current
      )

      entry
    rescue Stripe::StripeError => e
      entry.update!(
        stripe_transfer_status: "failed",
        stripe_transfer_error: e.message
      )
      raise Error, e.message
    end

    private

    attr_reader :entry, :actor

    def validate_entry!
      raise Error, "Only approved withdrawal requests can be transferred." unless entry.withdrawal_request? && entry.available?
      raise Error, "Only Stripe withdrawal requests can be transferred through Stripe." unless entry.stripe_payout?
    end

    def ensure_available_balance!(amount_cents)
      available_cents = platform_available_balance_cents
      return if available_cents >= amount_cents

      message = "Stripe available balance is #{money(available_cents)}, but this transfer needs #{money(amount_cents)}. Wait for pending funds to become available or add test-mode available balance before retrying."
      entry.update!(
        stripe_transfer_status: "failed",
        stripe_transfer_error: message
      )
      raise Error, message
    end

    def platform_available_balance_cents
      balance = Stripe::Balance.retrieve
      balance.available.sum do |amount|
        currency = amount.respond_to?(:currency) ? amount.currency : amount["currency"]
        cents = amount.respond_to?(:amount) ? amount.amount : amount["amount"]

        currency.to_s == "gbp" ? cents.to_i : 0
      end
    end

    def money(cents)
      format("£%.2f", cents.to_i / 100.0)
    end

    def transfer_status(transfer)
      return transfer.status if transfer.respond_to?(:status) && transfer.status.present?

      "paid"
    end
  end
end
