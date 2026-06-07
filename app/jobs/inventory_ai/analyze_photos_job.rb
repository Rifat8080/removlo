module InventoryAi
  class AnalyzePhotosJob < ApplicationJob
    queue_as :default

    def perform(estimate_id)
      estimate = QuotationInventoryEstimate.find_by(id: estimate_id)
      return if estimate.blank?
      return unless estimate.photos.attached?

      Analyzer.call(estimate: estimate)
      notify_operators(estimate)
    end

    private

    def notify_operators(estimate)
      status_label = estimate.processing_completed? ? "ready for review" : "needs attention"
      ::ActivityNotifier.call(
        recipients: User.operators,
        event_type: "inventory_ai.processed",
        title: "Inventory AI #{status_label}",
        body: "AI analysis for #{estimate.quotation.reference} is #{estimate.processing_status.humanize.downcase}.",
        url: Rails.application.routes.url_helpers.admin_quotation_path(estimate.quotation),
        notifiable: estimate
      )
    end
  end
end
