class Payslip < ApplicationRecord
  belongs_to :payroll_run
  belongs_to :employee, class_name: "User"

  validates :employee_role, presence: true
  validates :base_salary_cents, :bonus_cents, :commission_cents, :deductions_cents, :net_pay_cents,
            numericality: { greater_than_or_equal_to: 0 }
  validates :employee_id, uniqueness: { scope: :payroll_run_id }
  validate :employee_must_be_payroll_eligible

  before_validation :calculate_net_pay

  scope :recent, -> { joins(:payroll_run).order("payroll_runs.period_end DESC, payslips.created_at DESC") }
  scope :for_employee, ->(user) { where(employee: user).recent }

  def base_salary
    base_salary_cents.to_i / 100.0
  end

  def bonus
    bonus_cents.to_i / 100.0
  end

  def commission
    commission_cents.to_i / 100.0
  end

  def deductions
    deductions_cents.to_i / 100.0
  end

  def net_pay
    net_pay_cents.to_i / 100.0
  end

  private

  def calculate_net_pay
    self.net_pay_cents = base_salary_cents.to_i + bonus_cents.to_i + commission_cents.to_i - deductions_cents.to_i
  end

  def employee_must_be_payroll_eligible
    return if employee.blank?
    return if employee.admin? || employee.staff? || employee.driver?

    errors.add(:employee, "must be admin, staff, or driver")
  end
end
