require "test_helper"

module Users
  class RegistrationsControllerTest < ActionDispatch::IntegrationTest
    test "new registration can be opened for drivers" do
      get new_user_registration_path(role: "driver")

      assert_response :success
      assert_select "h1", text: "Join Removlo as a driver"
      assert_select "input[name='user[role]'][value='driver'][checked]"
    end

    test "driver sign up creates driver user and profile" do
      assert_difference "User.driver.count", 1 do
        assert_difference "DriverProfile.count", 1 do
          post user_registration_path, params: {
            user: {
              role: "driver",
              email: "new-driver@example.com",
              password: "password123",
              password_confirmation: "password123"
            }
          }
        end
      end

      assert_equal "driver", User.find_by!(email: "new-driver@example.com").role
    end

    test "public sign up does not allow privileged roles" do
      assert_difference "User.customer.count", 1 do
        assert_no_difference "User.admin.count" do
          post user_registration_path, params: {
            user: {
              role: "admin",
              email: "not-admin@example.com",
              password: "password123",
              password_confirmation: "password123"
            }
          }
        end
      end

      assert_equal "customer", User.find_by!(email: "not-admin@example.com").role
    end
  end
end
require "test_helper"

module Users
  class RegistrationsControllerTest < ActionDispatch::IntegrationTest
    test "customer can sign up with customer role" do
      assert_difference "User.count", 1 do
        post user_registration_path, params: {
          user: {
            email: "new-customer@example.com",
            password: "password123",
            password_confirmation: "password123",
            role: "customer"
          }
        }
      end

      assert_redirected_to dashboard_path
      assert User.find_by!(email: "new-customer@example.com").customer?
    end

    test "driver can sign up with driver role" do
      assert_difference "User.count", 1 do
        post user_registration_path, params: {
          user: {
            email: "new-driver@example.com",
            password: "password123",
            password_confirmation: "password123",
            role: "driver"
          }
        }
      end

      driver = User.find_by!(email: "new-driver@example.com")
      assert_redirected_to dashboard_path
      assert driver.driver?
      assert_not_nil driver.driver_profile
    end

    test "public signup cannot create admin users" do
      assert_difference "User.count", 1 do
        post user_registration_path, params: {
          user: {
            email: "not-admin@example.com",
            password: "password123",
            password_confirmation: "password123",
            role: "admin"
          }
        }
      end

      assert User.find_by!(email: "not-admin@example.com").customer?
    end
  end
end
