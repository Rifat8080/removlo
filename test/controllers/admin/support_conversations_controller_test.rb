require "test_helper"

class AdminSupportConversationsControllerTest < ActionDispatch::IntegrationTest
  TURBO_STREAM_HEADERS = { "Accept" => "text/vnd.turbo-stream.html" }.freeze

  test "admin can view support panel" do
    Conversations::FindOrCreateSupport.call(user: users(:customer), subject: "Help")
    sign_in users(:admin)

    get admin_support_conversations_path

    assert_response :success
    assert_match "Support Panel", response.body
  end

  test "customer cannot access admin support panel" do
    sign_in users(:customer)

    get admin_support_conversations_path

    assert_redirected_to dashboard_path
  end

  test "admin support reply responds with turbo stream form reset" do
    conversation = Conversations::FindOrCreateSupport.call(user: users(:customer), subject: "Help")
    sign_in users(:admin)

    post admin_support_conversation_messages_path(conversation),
      params: { message: { body: "We can help" } },
      headers: TURBO_STREAM_HEADERS

    assert_response :success
    assert_match ActionView::RecordIdentifier.dom_id(conversation, :messages), response.body
    assert_match "Internal note", response.body
    assert_match "We can help", response.body
  end
end
