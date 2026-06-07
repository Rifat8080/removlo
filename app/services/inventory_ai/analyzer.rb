module InventoryAi
  class Analyzer
    PROVIDERS = {
      "none" => Providers::NullProvider,
      "" => Providers::NullProvider,
      nil => Providers::NullProvider,
      "stub" => Providers::StubProvider
    }.freeze

    def self.call(estimate:)
      new(estimate).call
    end

    def initialize(estimate)
      @estimate = estimate
    end

    def call
      estimate.update!(processing_status: :processing)

      result = provider_class.call(estimate: estimate)

      if result.success
        estimate.update!(
          processing_status: :completed,
          estimate_status: :estimated,
          estimated_inventory: result.items,
          suggested_vehicle: result.suggested_vehicle,
          ai_provider: result.provider,
          ai_model: result.model,
          ai_raw_response: result.raw_response,
          ai_error: nil,
          processed_at: Time.current
        )
      else
        estimate.update!(
          processing_status: :failed,
          ai_provider: result.provider,
          ai_model: result.model,
          ai_raw_response: result.raw_response,
          ai_error: result.error,
          processed_at: Time.current
        )
      end

      result
    end

    private

    attr_reader :estimate

    def provider_class
      key = ENV.fetch("INVENTORY_AI_PROVIDER", "none").to_s.downcase
      PROVIDERS.fetch(key, Providers::NullProvider)
    end
  end
end
