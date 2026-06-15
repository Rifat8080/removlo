require "test_helper"

class AdminAuthorizationControllerTest < ActionDispatch::IntegrationTest
  test "staff can access operations dashboard and driver performance" do
    sign_in users(:staff)

    get admin_root_path
    assert_response :success

    get admin_driver_performances_path
    assert_response :success
  end

  test "staff cannot access admin only accounting area" do
    sign_in users(:staff)

    get admin_accounting_root_path
    assert_redirected_to dashboard_path
  end

  test "staff cannot access admin only shop area" do
    sign_in users(:staff)

    get admin_shop_products_path
    assert_redirected_to dashboard_path
  end

  test "staff cannot access admin only user management" do
    sign_in users(:staff)

    get admin_users_path
    assert_redirected_to dashboard_path
  end

  test "staff cannot access admin only blog management" do
    sign_in users(:staff)

    get admin_blog_posts_path
    assert_redirected_to dashboard_path
  end
end
