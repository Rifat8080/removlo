module Admin
  module Shop
    class ProductsController < BaseController
      before_action :set_product, only: %i[edit update destroy]

      def index
        @products = Product.includes(:product_category).with_attached_image.order(:name)
      end

      def new
        @product = Product.new(status: :active)
        @categories = ProductCategory.ordered
      end

      def edit
        @categories = ProductCategory.ordered
      end

      def create
        @product = Product.new(product_params)
        if @product.save
          redirect_to admin_shop_products_path, notice: "Product created."
        else
          @categories = ProductCategory.ordered
          render :new, status: :unprocessable_entity
        end
      end

      def update
        if @product.update(product_params)
          redirect_to admin_shop_products_path, notice: "Product updated."
        else
          @categories = ProductCategory.ordered
          render :edit, status: :unprocessable_entity
        end
      end

      def destroy
        @product.destroy
        redirect_to admin_shop_products_path, notice: "Product deleted."
      end

      private

      def set_product
        @product = Product.find_by_param!(params[:id])
      end

      def product_params
        attrs = params.require(:product).permit(
          :product_category_id, :name, :slug, :sku, :description, :price,
          :stock_quantity, :status, :featured, :image
        )
        parse_price_param(attrs)
      end
    end
  end
end
