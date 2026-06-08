require "test_helper"

class MessagesControllerTest < ActionDispatch::IntegrationTest
  test "message creation notifies other participants" do
    conversation = Conversations::FindOrCreateSupport.call(user: users(:customer), subject: "Help")
    sign_in users(:customer)

    assert_difference "Message.count", 1 do
      assert_difference -> { users(:admin).notifications.count }, 1 do
        post conversation_messages_path(conversation), params: { message: { body: "Hello support" } }
      end
    end
  end

  test "non participant cannot post message" do
    conversation = Conversations::FindOrCreateSupport.call(user: users(:admin), subject: "Private")
    sign_in users(:driver_a)

    post conversation_messages_path(conversation), params: { message: { body: "Intrusion" } }

    assert_response :not_found
  end

  test "cannot post to closed conversation" do
    conversation = Conversations::FindOrCreateSupport.call(user: users(:customer), subject: "Closed")
    conversation.update!(status: :closed)
    sign_in users(:customer)

    assert_no_difference "Message.count" do
      post conversation_messages_path(conversation), params: { message: { body: "Anyone there?" } }
    end

    assert_redirected_to conversation_path(conversation)
  end
end
