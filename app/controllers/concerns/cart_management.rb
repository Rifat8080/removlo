module CartManagement
  extend ActiveSupport::Concern

  included do
    helper_method :current_cart
  end

  private

  def current_cart
    @current_cart ||= Shop::CurrentCart.call(self)
  end
end
