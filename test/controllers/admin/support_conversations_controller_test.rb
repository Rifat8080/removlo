require "test_helper"

class AdminSupportConversationsControllerTest < ActionDispatch::IntegrationTest
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
end
