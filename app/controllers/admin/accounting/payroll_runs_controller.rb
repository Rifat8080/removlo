module Admin
  module Accounting
    class PayrollRunsController < BaseController
      before_action :set_payroll_run, only: %i[show edit update destroy finalize mark_paid]

      def index
        @payroll_runs = PayrollRun.includes(:created_by, :payslips).recent
      end

      def show
        @payslips = @payroll_run.payslips.includes(:employee)
      end

      def new
        @payroll_run = PayrollRun.new(
          period_start: Date.current.beginning_of_month,
          period_end: Date.current.end_of_month
        )
      end

      def edit
      end

      def create
        @payroll_run = PayrollRun.new(payroll_run_params.merge(created_by: current_user))
        if @payroll_run.save
          redirect_to admin_accounting_payroll_run_path(@payroll_run), notice: "Payroll run created."
        else
          render :new, status: :unprocessable_entity
        end
      end

      def update
        if @payroll_run.update(payroll_run_params)
          redirect_to admin_accounting_payroll_run_path(@payroll_run), notice: "Payroll run updated."
        else
          render :edit, status: :unprocessable_entity
        end
      end

      def destroy
        if @payroll_run.paid?
          redirect_to admin_accounting_payroll_runs_path, alert: "Paid payroll runs cannot be deleted."
          return
        end

        @payroll_run.destroy
        redirect_to admin_accounting_payroll_runs_path, notice: "Payroll run deleted."
      end

      def finalize
        @payroll_run.update!(status: :finalized)
        redirect_to admin_accounting_payroll_run_path(@payroll_run), notice: "Payroll run finalized."
      end

      def mark_paid
        @payroll_run.update!(status: :paid)
        redirect_to admin_accounting_payroll_run_path(@payroll_run), notice: "Payroll marked as paid. Payslips and expenses recorded."
      end

      private

      def set_payroll_run
        @payroll_run = PayrollRun.find(params[:id])
      end

      def payroll_run_params
        params.require(:payroll_run).permit(:period_start, :period_end, :status, :notes)
      end
    end
  end
end
