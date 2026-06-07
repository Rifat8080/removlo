require "test_helper"

class ConversationsControllerTest < ActionDispatch::IntegrationTest
  test "customer cannot access another users conversation" do
    conversation = Conversations::FindOrCreateSupport.call(user: users(:admin), subject: "Ops only")
    sign_in users(:customer)

    get conversation_path(conversation)

    assert_response :not_found
  end

  test "customer can create support conversation" do
    sign_in users(:customer)

    assert_difference "Conversation.support.count", 1 do
      post conversations_path, params: { conversation: { subject: "Need help" } }
    end

    assert_redirected_to conversation_path(Conversation.support.last)
  end

  test "customer can open job chat after deposit paid" do
    sign_in users(:customer)

    post conversations_path, params: { quotation_id: quotations(:booked_job).id }

    assert_redirected_to conversation_path(Conversation.job.last)
  end
end
