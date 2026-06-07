require "test_helper"

class InventoryAiAnalyzerTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  test "null provider marks estimate failed without crashing" do
    estimate = quotation_inventory_estimates(:marketplace_estimate)

    result = InventoryAi::Analyzer.call(estimate: estimate)

    assert_not result.success
    estimate.reload
    assert_equal "failed", estimate.processing_status
    assert_includes estimate.ai_error, "not configured"
  end

  test "stub provider persists structured inventory output" do
    estimate = quotation_inventory_estimates(:marketplace_estimate)
    ENV["INVENTORY_AI_PROVIDER"] = "stub"

    result = InventoryAi::Analyzer.call(estimate: estimate)

    assert result.success
    estimate.reload
    assert_equal "completed", estimate.processing_status
    assert_equal "estimated", estimate.estimate_status
    assert_equal "7_5_ton_luton", estimate.suggested_vehicle
    assert_equal 4, estimate.estimated_inventory.size
  ensure
    ENV.delete("INVENTORY_AI_PROVIDER")
  end

  test "photo upload enqueues analysis job" do
    estimate = quotation_inventory_estimates(:marketplace_estimate)
    estimate.photos.attach(
      io: StringIO.new("fake-image-data"),
      filename: "inventory.jpg",
      content_type: "image/jpeg"
    )

    assert_enqueued_with(job: InventoryAi::AnalyzePhotosJob) do
      estimate.enqueue_analysis!
    end
  end
end
