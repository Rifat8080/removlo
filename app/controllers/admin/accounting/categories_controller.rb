module Admin
  module Accounting
    class CategoriesController < BaseController
      before_action :set_category, only: %i[edit update destroy]

      def index
        authorize! :read, AccountingCategory
        @categories = AccountingCategory.ordered
      end

      def new
        @category = AccountingCategory.new
        authorize! :create, @category
      end

      def edit
        authorize! :update, @category
      end

      def create
        @category = AccountingCategory.new(category_params)
        authorize! :create, @category

        if @category.save
          redirect_to admin_accounting_categories_path, notice: "Category created."
        else
          render :new, status: :unprocessable_entity
        end
      end

      def update
        authorize! :update, @category

        if @category.update(category_params)
          redirect_to admin_accounting_categories_path, notice: "Category updated."
        else
          render :edit, status: :unprocessable_entity
        end
      end

      def destroy
        authorize! :destroy, @category

        @category.destroy
        redirect_to admin_accounting_categories_path, notice: "Category deleted."
      rescue ActiveRecord::DeleteRestrictionError
        redirect_to admin_accounting_categories_path, alert: "Category is in use and cannot be deleted."
      end

      private

      def set_category
        @category = AccountingCategory.find(params[:id])
      end

      def category_params
        params.require(:accounting_category).permit(:name, :slug, :category_type, :description)
      end
    end
  end
end
