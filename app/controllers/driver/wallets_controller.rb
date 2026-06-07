module Driver
  class WalletsController < BaseController
    def show
      @entries = current_user.driver_wallet_entries.recent
      @pending_cents = current_user.wallet_pending_cents
      @available_cents = current_user.wallet_available_cents
      @total_cents = current_user.wallet_balance_cents
    end
  end
end
