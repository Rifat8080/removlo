module Admin
  module Accounting
    class ReportsController < BaseController
      def index
        authorize! :read, AccountingTransaction

        @start_date = parse_date(params[:start_date]) || Date.current.beginning_of_month
        @end_date = parse_date(params[:end_date]) || Date.current.end_of_month
        @transactions = AccountingTransaction.includes(:accounting_category, :user, :quotation)
                                             .in_period(@start_date, @end_date)
                                             .recent
        @transactions = @transactions.where(transaction_type: params[:type]) if params[:type].present?
        @transactions = @transactions.where(accounting_category_id: params[:category_id]) if params[:category_id].present?
        @transactions = @transactions.where(user_id: params[:user_id]) if params[:user_id].present?
        @transactions = @transactions.where(quotation_id: params[:quotation_id]) if params[:quotation_id].present?

        @summary = AccountingTransaction.summary_for(start_date: @start_date, end_date: @end_date)
        @monthly = monthly_breakdown(@start_date, @end_date)
        @categories = AccountingCategory.ordered
        @users = User.order(:email)
      end

      private

      def parse_date(value)
        return if value.blank?

        Date.parse(value)
      rescue ArgumentError
        nil
      end

      def monthly_breakdown(start_date, end_date)
        grouped = AccountingTransaction.in_period(start_date, end_date)
                                       .group(Arel.sql("DATE_TRUNC('month', transaction_date)"))
                                       .group(:transaction_type)
                                       .sum(:amount_cents)
                                       .each_with_object(Hash.new { |h, k| h[k] = {} }) do |((month, type), cents), result|
          key = month.to_date.strftime("%Y-%m")
          result[key][type] = cents
          result[key][:income] = result[key].values_at(*AccountingTransaction::INCOME_TYPES).compact.sum
          result[key][:expenses] = result[key].values_at(*AccountingTransaction::EXPENSE_TYPES).compact.sum
          result[key][:net] = result[key][:income] - result[key][:expenses]
        end

        grouped.each_key do |month|
          month_date = Date.strptime(month, "%Y-%m")
          summary = AccountingTransaction.summary_for(start_date: month_date.beginning_of_month, end_date: month_date.end_of_month)
          grouped[month][:driver_cost] = summary[:driver_cost_cents]
          grouped[month][:total_revenue] = summary[:total_revenue_cents]
        end

        grouped.sort.reverse
      end
    end
  end
end
