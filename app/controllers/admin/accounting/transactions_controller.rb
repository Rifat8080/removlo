module Admin
  module Accounting
    class TransactionsController < BaseController
      before_action :set_transaction, only: %i[show edit update destroy]

      def index
        @transactions = AccountingTransaction.includes(:accounting_category, :user, :quotation).recent
        @transactions = @transactions.where(transaction_type: params[:type]) if params[:type].present?
        @transactions = @transactions.where(accounting_category_id: params[:category_id]) if params[:category_id].present?
        if params[:start_date].present? && params[:end_date].present?
          @transactions = @transactions.in_period(Date.parse(params[:start_date]), Date.parse(params[:end_date]))
        end
        @summary = AccountingTransaction.summary_for(
          scope: @transactions.unscope(:order),
          start_date: params[:start_date].presence && Date.parse(params[:start_date]),
          end_date: params[:end_date].presence && Date.parse(params[:end_date])
        ) if params[:start_date].present? || params[:type].present? || params[:category_id].present?
        @summary ||= AccountingTransaction.summary_for
        @categories = AccountingCategory.ordered
      end

      def show
      end

      def new
        @transaction = AccountingTransaction.new(transaction_date: Date.current, salary_payment_status: :paid)
      end

      def edit
      end

      def create
        @transaction = AccountingTransaction.new(transaction_params)
        if @transaction.save
          redirect_to admin_accounting_transaction_path(@transaction), notice: "Transaction recorded."
        else
          render :new, status: :unprocessable_entity
        end
      end

      def update
        if @transaction.update(transaction_params)
          redirect_to admin_accounting_transaction_path(@transaction), notice: "Transaction updated."
        else
          render :edit, status: :unprocessable_entity
        end
      end

      def destroy
        if @transaction.quotation_payment_id.present?
          redirect_to admin_accounting_transactions_path, alert: "Payment-linked transactions cannot be deleted manually."
          return
        end

        @transaction.destroy
        redirect_to admin_accounting_transactions_path, notice: "Transaction deleted."
      end

      private

      def set_transaction
        @transaction = AccountingTransaction.find(params[:id])
      end

      def transaction_params
        attrs = params.require(:accounting_transaction).permit(
          :accounting_category_id, :user_id, :quotation_id, :transaction_type,
          :transaction_date, :description, :vendor_payee, :payment_method, :reference, :amount,
          :salary_payment_status
        )
        parse_amount_param(attrs)
      end
    end
  end
end
