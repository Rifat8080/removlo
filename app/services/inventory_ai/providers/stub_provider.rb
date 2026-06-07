module InventoryAi
  module Providers
    class StubProvider < Base
      def call
        success_result(
          items: [
            { "name" => "Sofa", "quantity" => 2 },
            { "name" => "Fridge", "quantity" => 1 },
            { "name" => "Bed", "quantity" => 3 },
            { "name" => "Boxes", "quantity" => 20 }
          ],
          suggested_vehicle: "7_5_ton_luton",
          provider: "stub",
          model: "test",
          raw_response: { source: "stub_provider" }
        )
      end
    end
  end
end
