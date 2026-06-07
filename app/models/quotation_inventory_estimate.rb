class QuotationInventoryEstimate < ApplicationRecord
  ESTIMATE_STATUSES = {
    pending: "pending",
    estimated: "estimated",
    reviewed: "reviewed"
  }.freeze

  PROCESSING_STATUSES = {
    pending: "pending",
    processing: "processing",
    completed: "completed",
    failed: "failed"
  }.freeze

  belongs_to :quotation

  has_many_attached :photos

  enum :estimate_status, ESTIMATE_STATUSES, default: :pending, validate: true
  enum :processing_status, PROCESSING_STATUSES, default: :pending, prefix: :processing, validate: true

  def inventory_lines
    estimated_inventory.map do |item|
      quantity = item["quantity"] || item[:quantity]
      name = item["name"] || item[:name]
      "#{quantity} x #{name}"
    end
  end

  def enqueue_analysis!
    update!(processing_status: :pending, ai_error: nil)
    InventoryAi::AnalyzePhotosJob.perform_later(id)
  end

  def ai_status_label
    if processing_processing?
      "Analyzing photos..."
    elsif processing_completed?
      "AI estimate ready"
    elsif processing_failed?
      ai_error.presence || "AI analysis failed"
    else
      "Waiting for analysis"
    end
  end
end
