class Rack::Attack
  Rack::Attack.cache.store = Rails.cache

  safelist("health checks") do |request|
    request.path == "/up"
  end

  throttle("logins/ip", limit: 5, period: 20.seconds) do |request|
    request.ip if request.post? && request.path == "/users/sign_in"
  end

  throttle("logins/email", limit: 5, period: 20.seconds) do |request|
    if request.post? && request.path == "/users/sign_in"
      request.params.dig("user", "email").to_s.downcase.presence
    end
  end

  throttle("password_resets/ip", limit: 5, period: 1.minute) do |request|
    request.ip if request.post? && request.path == "/users/password"
  end

  throttle("registrations/ip", limit: 5, period: 1.minute) do |request|
    request.ip if request.post? && request.path == "/users"
  end

  throttle("quotation_requests/ip", limit: 10, period: 1.minute) do |request|
    request.ip if request.post? && request.path == "/quotations"
  end

  throttle("checkout_and_cart/ip", limit: 30, period: 1.minute) do |request|
    request.ip if request.post? && request.path.in?(%w[/cart/add /checkout])
  end

  self.throttled_responder = lambda do |_request|
    [
      429,
      { "Content-Type" => "text/plain", "Retry-After" => "60" },
      [ "Too many requests. Please wait and try again." ]
    ]
  end
end
