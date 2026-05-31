module Admin
  module Shop
    class ProductCategoriesController < BaseController
      before_action :set_category, only: %i[edit update destroy]

      def index
        @categories = ProductCategory.ordered.includes(:products)
      end

      def new
        @category = ProductCategory.new
      end

      def edit
      end

      def create
        @category = ProductCategory.new(category_params)
        if @category.save
          redirect_to admin_shop_product_categories_path, notice: "Category created."
        else
          render :new, status: :unprocessable_entity
        end
      end

      def update
        if @category.update(category_params)
          redirect_to admin_shop_product_categories_path, notice: "Category updated."
        else
          render :edit, status: :unprocessable_entity
        end
      end

      def destroy
        @category.destroy
        redirect_to admin_shop_product_categories_path, notice: "Category deleted."
      rescue ActiveRecord::DeleteRestrictionError
        redirect_to admin_shop_product_categories_path, alert: "Category has products and cannot be deleted."
      end

      private

      def set_category
        @category = ProductCategory.find(params[:id])
      end

      def category_params
        params.require(:product_category).permit(:name, :slug, :description, :position)
      end
    end
  end
end
