module Shop
  class CurrentCart
    def self.call(controller)
      new(controller).call
    end

    def initialize(controller)
      @controller = controller
      @user = controller.current_user if controller.user_signed_in?
      @session = controller.session
    end

    def call
      cart = find_or_create_cart
      ensure_session_token!(cart)
      cart
    end

    private

    attr_reader :controller, :user, :session

    def find_or_create_cart
      if user.present?
        Cart.find_or_create_by!(user: user)
      else
        token = session[:cart_token]
        cart = Cart.find_by(session_token: token) if token.present?
        cart || Cart.create!(session_token: SecureRandom.urlsafe_base64(24)).tap do |new_cart|
          session[:cart_token] = new_cart.session_token
        end
      end
    end

    def ensure_session_token!(cart)
      return if cart.session_token.present?

      cart.update!(session_token: SecureRandom.urlsafe_base64(24))
      session[:cart_token] = cart.session_token unless user.present?
    end
  end
end
