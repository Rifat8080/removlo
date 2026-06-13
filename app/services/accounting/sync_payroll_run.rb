module Accounting
  class SyncPayrollRun
    def self.call(payroll_run, actor: nil)
      new(payroll_run, actor: actor).call
    end

    def initialize(payroll_run, actor: nil)
      @payroll_run = payroll_run
      @actor = actor
    end

    def call
      return unless payroll_run.paid?

      payroll_run.payslips.includes(:employee).find_each do |payslip|
        sync_payslip_transactions(payslip)
        notify_payslip(payslip)
      end
    end

    private

    attr_reader :payroll_run, :actor

    def sync_payslip_transactions(payslip)
      sync_amount(
        payslip: payslip,
        transaction_type: :salary,
        amount_cents: payslip.base_salary_cents + payslip.bonus_cents,
        description: "Salary – #{payroll_run.period_label}",
        category: salary_category
      )

      return unless payslip.commission_cents.positive?

      sync_amount(
        payslip: payslip,
        transaction_type: :commission,
        amount_cents: payslip.commission_cents,
        description: "Commission – #{payroll_run.period_label}",
        category: commission_category,
        suffix: "commission"
      )
    end

    def sync_amount(payslip:, transaction_type:, amount_cents:, description:, category:, suffix: nil)
      return if amount_cents.to_i <= 0

      reference = payroll_reference(payslip, suffix)
      transaction = AccountingTransaction.find_or_initialize_by(reference: reference)
      transaction.assign_attributes(
        transaction_type: transaction_type,
        salary_payment_status: transaction_type.to_s == "salary" ? :paid : nil,
        amount_cents: amount_cents,
        transaction_date: payslip.payment_date || payroll_run.period_end,
        description: description,
        vendor_payee: payslip.employee.email,
        payment_method: "bank_transfer",
        user: payslip.employee,
        accounting_category: category
      )
      transaction.save!
    end

    def payroll_reference(payslip, suffix = nil)
      parts = ["PAY", payroll_run.id, payslip.employee_id]
      parts << suffix if suffix.present?
      parts.join("-")
    end

    def salary_category
      AccountingCategory.default_for(:salary) || AccountingCategory.find_by!(slug: "salaries")
    end

    def commission_category
      AccountingCategory.default_for(:commission) || AccountingCategory.find_by!(slug: "commissions")
    end

    def notify_payslip(payslip)
      ::ActivityNotifier.call(
        recipients: payslip.employee,
        event_type: "accounting.payslip",
        title: "Payslip for #{payroll_run.period_label}",
        body: "Your net pay is #{format('£%.2f', payslip.net_pay)}.",
        url: Rails.application.routes.url_helpers.payslip_path(payslip),
        actor: actor,
        notifiable: payslip
      )
    end
  end
end
