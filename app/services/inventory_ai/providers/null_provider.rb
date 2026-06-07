module InventoryAi
  module Providers
    class NullProvider < Base
      def call
        failure_result(
          provider: "none",
          model: "disabled",
          error: "Inventory AI provider is not configured. Set INVENTORY_AI_PROVIDER to enable analysis.",
          raw_response: { configured: false }
        )
      end
    end
  end
end
