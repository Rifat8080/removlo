require "test_helper"

class Admin::Accounting::TransactionsControllerTest < ActionDispatch::IntegrationTest
  test "new transaction form uses salary payment status without commission payroll option" do
    sign_in users(:admin)

    get new_admin_accounting_transaction_path

    assert_response :success
    assert_match "Salary payment status", response.body
    assert_match "Beneficiary / linked user", response.body
    assert_no_match "Commission", response.body
  end

  test "admin salary transaction notifies beneficiary when paid" do
    sign_in users(:admin)
    beneficiary = users(:staff)

    assert_difference -> { AccountingTransaction.salary.count }, 1 do
      assert_difference -> { Notification.where(user: beneficiary, event_type: "accounting.salary_paid").count }, 1 do
        post admin_accounting_transactions_path, params: {
          accounting_transaction: {
            transaction_type: "salary",
            salary_payment_status: "paid",
            user_id: beneficiary.id,
            amount: "125.00",
            transaction_date: Date.current,
            description: "June salary",
            payment_method: "bank transfer",
            reference: "SAL-JUNE"
          }
        }
      end
    end

    transaction = AccountingTransaction.salary.order(:created_at).last
    assert_redirected_to admin_accounting_transaction_path(transaction)
    assert_equal "paid", transaction.salary_payment_status
  end
end
