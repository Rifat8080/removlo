class PayslipsController < ApplicationController
  before_action :authenticate_user!
  before_action :require_payroll_eligible!
  before_action :set_payslip, only: %i[show pdf]

  layout "dashboard"

  def index
    @payslips = current_user.payslips.includes(:payroll_run)
  end

  def show
    authorize_payslip!
  end

  def pdf
    authorize_payslip!
    send_data(
      Pdf::PayslipPdf.new(@payslip).render,
      filename: "payslip-#{@payslip.payroll_run.period_end.strftime('%Y-%m')}.pdf",
      type: "application/pdf",
      disposition: "attachment"
    )
  end

  private

  def require_payroll_eligible!
    return if current_user.admin? || current_user.staff? || current_user.driver?

    redirect_to dashboard_path, alert: "Payslips are only available for team members."
  end

  def set_payslip
    @payslip = Payslip.find(params[:id])
  end

  def authorize_payslip!
    return if @payslip.employee_id == current_user.id

    redirect_to payslips_path, alert: "You are not authorized to view this payslip."
  end
end
