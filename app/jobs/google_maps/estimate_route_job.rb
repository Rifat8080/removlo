module GoogleMaps
  class EstimateRouteJob < ApplicationJob
    queue_as :default

    def perform(quotation_id)
      quotation = Quotation.find_by(id: quotation_id)
      return unless quotation

      ApplyRouteEstimate.call(quotation: quotation)
    end
  end
end
