module Admin
  module Accounting
    class PayslipsController < BaseController
      before_action :set_payroll_run
      before_action :set_payslip, only: %i[edit update destroy pdf]

      def new
        @payslip = @payroll_run.payslips.new(payment_date: @payroll_run.period_end)
        authorize! :create, @payslip
        @employees = User.payroll_eligible
      end

      def edit
        authorize! :update, @payslip
        @employees = User.payroll_eligible
      end

      def create
        @payslip = @payroll_run.payslips.new(payslip_params)
        authorize! :create, @payslip

        if @payslip.save
          redirect_to admin_accounting_payroll_run_path(@payroll_run), notice: "Payslip added."
        else
          @employees = User.payroll_eligible
          render :new, status: :unprocessable_entity
        end
      end

      def update
        authorize! :update, @payslip

        if @payslip.update(payslip_params)
          redirect_to admin_accounting_payroll_run_path(@payroll_run), notice: "Payslip updated."
        else
          @employees = User.payroll_eligible
          render :edit, status: :unprocessable_entity
        end
      end

      def destroy
        authorize! :destroy, @payslip

        if @payroll_run.paid?
          redirect_to admin_accounting_payroll_run_path(@payroll_run), alert: "Cannot remove payslips from a paid run."
          return
        end

        @payslip.destroy
        redirect_to admin_accounting_payroll_run_path(@payroll_run), notice: "Payslip removed."
      end

      def pdf
        authorize! :pdf, @payslip

        send_data(
          Pdf::PayslipPdf.new(@payslip).render,
          filename: "payslip-#{@payslip.employee.email.parameterize}-#{@payroll_run.period_end.strftime('%Y-%m')}.pdf",
          type: "application/pdf",
          disposition: "attachment"
        )
      end

      private

      def set_payroll_run
        @payroll_run = PayrollRun.find(params[:payroll_run_id])
      end

      def set_payslip
        @payslip = @payroll_run.payslips.find(params[:id])
      end

      def payslip_params
        attrs = params.require(:payslip).permit(
          :employee_id, :employee_role, :payment_date, :notes,
          :base_salary, :bonus, :commission, :deductions
        )
        employee = User.find_by(id: attrs[:employee_id])
        attrs[:employee_role] = employee.role if employee && attrs[:employee_role].blank?
        parse_money_param(attrs, :base_salary)
        parse_money_param(attrs, :bonus)
        parse_money_param(attrs, :commission)
        parse_money_param(attrs, :deductions)
        attrs
      end
    end
  end
end
