class PayslipsController < ApplicationController
  before_action :authenticate_user!
  before_action :require_payroll_eligible!
  before_action :set_payslip, only: %i[show pdf]

  layout "dashboard"

  def index
    authorize! :read, Payslip
    @payslips = current_user.payslips.includes(:payroll_run)
  end

  def show
    authorize! :read, @payslip
  end

  def pdf
    authorize! :pdf, @payslip
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
end
