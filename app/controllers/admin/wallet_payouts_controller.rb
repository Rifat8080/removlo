module Admin
  class WalletPayoutsController < BaseController
    before_action :require_admin!, except: :index
    before_action :set_entry, only: %i[approve payout]

    def index
      @pending_entries = DriverWalletEntry
                         .where("(entry_type = :earning AND status = :pending_status) OR (entry_type = :withdrawal AND status IN (:withdrawal_statuses))",
                                earning: DriverWalletEntry.entry_types[:job_earning],
                                pending_status: DriverWalletEntry.statuses[:pending],
                                withdrawal: DriverWalletEntry.entry_types[:withdrawal_request],
                                withdrawal_statuses: %w[pending available])
                         .includes(:driver, :quotation)
                         .recent
    end

    def approve
      @entry.approve!(actor: current_user)
      redirect_to admin_wallet_payouts_path, notice: "Wallet entry approved and available for payout."
    rescue ActiveRecord::RecordInvalid => e
      redirect_to admin_wallet_payouts_path, alert: e.record.errors.full_messages.to_sentence
    end

    def payout
      unless @entry.withdrawal_request?
        redirect_to admin_wallet_payouts_path, alert: "Approve job earnings into the driver's wallet. Drivers must request cash or Stripe withdrawals before payout."
        return
      end

      payout_withdrawal_request
    rescue ::Stripe::DriverTransfer::Error, ActiveRecord::RecordInvalid => e
      message = e.respond_to?(:record) ? e.record.errors.full_messages.to_sentence : e.message
      redirect_to admin_wallet_payouts_path, alert: message
    end

    private

    def payout_withdrawal_request
      if @entry.cash_payout?
        @entry.mark_withdrawn!
        @entry.update!(approved_by: current_user, approved_at: Time.current)
        redirect_to admin_wallet_payouts_path, notice: "Cash payout of #{helpers.money_from_cents(@entry.amount_cents.abs)} marked as paid."
      else
        ::Stripe::DriverTransfer.call(entry: @entry, actor: current_user)
        redirect_to admin_wallet_payouts_path, notice: "Stripe transfer of #{helpers.money_from_cents(@entry.amount_cents.abs)} sent to the driver."
      end
    end

    def set_entry
      @entry = DriverWalletEntry.find(params[:id])
    end
  end
end
