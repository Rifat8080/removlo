require "test_helper"

class Admin::UsersControllerTest < ActionDispatch::IntegrationTest
  test "admin can change another user's role" do
    sign_in users(:admin)
    customer = users(:customer)

    patch admin_user_path(customer), params: {
      user: {
        email: customer.email,
        role: "staff"
      }
    }

    assert_redirected_to admin_user_path(customer)
    assert_equal "staff", customer.reload.role
  end

  test "admin cannot change their own role" do
    admin = users(:admin)
    sign_in admin

    patch admin_user_path(admin), params: {
      user: {
        email: admin.email,
        role: "customer"
      }
    }

    assert_redirected_to admin_user_path(admin)
    assert_equal "admin", admin.reload.role
  end

  test "admin cannot assign an invalid role" do
    sign_in users(:admin)
    customer = users(:customer)

    patch admin_user_path(customer), params: {
      user: {
        email: customer.email,
        role: "super_admin"
      }
    }

    assert_redirected_to admin_user_path(customer)
    assert_equal "customer", customer.reload.role
  end

  test "admin self edit renders role as read only" do
    admin = users(:admin)
    sign_in admin

    get edit_admin_user_path(admin)

    assert_response :success
    assert_match "Admins cannot change their own role", response.body
    assert_no_match "name=\"user[role]\"", response.body
  end
end
