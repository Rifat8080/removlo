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

      assert_redirected_to dashboard_path
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

    test "driver signup returns to shared job when return_to is provided" do
      quotation = quotations(:marketplace_job)
      return_path = public_job_path(quotation.public_share_token)

      get new_user_registration_path(role: "driver", return_to: return_path)

      post user_registration_path, params: {
        user: {
          role: "driver",
          email: "outside-driver@example.com",
          password: "password123",
          password_confirmation: "password123"
        }
      }

      assert_redirected_to return_path
    end

    test "account update does not allow users to change their own role" do
      user = users(:customer)
      sign_in user

      patch user_registration_path, params: {
        user: {
          email: user.email,
          role: "driver",
          current_password: "password123"
        }
      }

      assert_equal "customer", user.reload.role
    end
  end
end
