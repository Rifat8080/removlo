require "test_helper"

class MessagesControllerTest < ActionDispatch::IntegrationTest
  TURBO_STREAM_HEADERS = { "Accept" => "text/vnd.turbo-stream.html" }.freeze

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

  test "message creation responds with targeted turbo stream updates" do
    conversation = Conversations::FindOrCreateSupport.call(user: users(:customer), subject: "Realtime help")
    sign_in users(:customer)

    post conversation_messages_path(conversation),
      params: { message: { body: "Hello over Turbo" } },
      headers: TURBO_STREAM_HEADERS

    assert_response :success
    assert_includes response.media_type, "text/vnd.turbo-stream.html"
    assert_match ActionView::RecordIdentifier.dom_id(conversation, :messages), response.body
    assert_match ActionView::RecordIdentifier.dom_id(conversation, :message_form), response.body
    assert_match "Hello over Turbo", response.body
  end

  test "blank turbo message renders inline form error" do
    conversation = Conversations::FindOrCreateSupport.call(user: users(:customer), subject: "Validation help")
    sign_in users(:customer)

    assert_no_difference "Message.count" do
      post conversation_messages_path(conversation),
        params: { message: { body: "" } },
        headers: TURBO_STREAM_HEADERS
    end

    assert_response :unprocessable_entity
    assert_match ActionView::RecordIdentifier.dom_id(conversation, :message_form), response.body
    assert_match "Body can&#39;t be blank", response.body
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
