module Admin
  class WalletPayoutsController < BaseController
    before_action :set_entry, only: %i[approve payout]

    def index
      @pending_entries = DriverWalletEntry.where(status: %w[pending available]).includes(:driver, :quotation).recent
    end

    def approve
      @entry.approve!(actor: current_user)
      redirect_to admin_wallet_payouts_path, notice: "Wallet entry approved and available for payout."
    rescue ActiveRecord::RecordInvalid => e
      redirect_to admin_wallet_payouts_path, alert: e.record.errors.full_messages.to_sentence
    end

    def payout
      DriverWalletEntry.transaction do
        @entry.reload
        if @entry.withdrawal_request?
          @entry.mark_withdrawn!
        else
          @entry.mark_withdrawn!
          DriverWalletEntry.create!(
            driver: @entry.driver,
            quotation: @entry.quotation,
            entry_type: :payout,
            status: :withdrawn,
            amount_cents: -@entry.amount_cents,
            reference: "PAYOUT-#{SecureRandom.hex(4).upcase}",
            notes: "Payout for #{@entry.reference || @entry.id}",
            approved_by: current_user,
            approved_at: Time.current
          )
        end
      end
      redirect_to admin_wallet_payouts_path, notice: "Payout of #{helpers.money_from_cents(@entry.amount_cents.abs)} processed."
    rescue ActiveRecord::RecordInvalid => e
      redirect_to admin_wallet_payouts_path, alert: e.record.errors.full_messages.to_sentence
    end

    private

    def set_entry
      @entry = DriverWalletEntry.find(params[:id])
    end
  end
end
