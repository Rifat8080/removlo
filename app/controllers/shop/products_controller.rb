module Shop
  class ProductsController < ApplicationController
    layout "landing"

    def index
      @categories = ProductCategory.ordered.includes(:products)
      @featured = Product.featured.with_attached_image.limit(4)
      @products = Product.catalog.with_attached_image
      @products = @products.where(product_category_id: params[:category]) if params[:category].present?
      @products = @products.where.not(id: @featured.select(:id)) if params[:category].blank? && @featured.any?
    end

    def show
      @product = Product.catalog.with_attached_image.by_param(params[:slug]).first!
      @related = Product.catalog.where(product_category: @product.product_category).where.not(id: @product.id).with_attached_image.limit(4)
    end
  end
end
