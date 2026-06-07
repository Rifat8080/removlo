require "test_helper"

class ConversationTest < ActiveSupport::TestCase
  test "job chat blocked before deposit protection" do
    quotation = quotations(:booked_job)
    quotation.update_column(:payment_status, "unpaid")

    assert_raises(ActiveRecord::RecordNotFound) do
      Conversations::FindOrCreateJob.call(quotation: quotation, actor: users(:customer))
    end
  end

  test "job chat allowed after deposit paid" do
    quotation = quotations(:booked_job)

    conversation = Conversations::FindOrCreateJob.call(quotation: quotation, actor: users(:customer))

    assert conversation.job?
    assert_includes conversation.participants, users(:customer)
    assert_includes conversation.participants, users(:driver_a)
  end

  test "support conversation includes user and operators" do
    conversation = Conversations::FindOrCreateSupport.call(user: users(:customer), subject: "Help")

    assert conversation.support?
    assert_includes conversation.participants, users(:customer)
    assert_includes conversation.participants, users(:admin)
  end
end
