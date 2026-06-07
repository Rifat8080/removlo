module InventoryAi
  module Providers
    class Base
      Result = Struct.new(:success, :items, :suggested_vehicle, :provider, :model, :raw_response, :error, keyword_init: true)

      def self.call(estimate:)
        new(estimate).call
      end

      def initialize(estimate)
        @estimate = estimate
      end

      def call
        raise NotImplementedError
      end

      private

      attr_reader :estimate

      def success_result(items:, suggested_vehicle:, provider:, model:, raw_response: {})
        Result.new(
          success: true,
          items: items,
          suggested_vehicle: suggested_vehicle,
          provider: provider,
          model: model,
          raw_response: raw_response,
          error: nil
        )
      end

      def failure_result(error:, provider: nil, model: nil, raw_response: {})
        Result.new(
          success: false,
          items: [],
          suggested_vehicle: nil,
          provider: provider,
          model: model,
          raw_response: raw_response,
          error: error
        )
      end
    end
  end
end
