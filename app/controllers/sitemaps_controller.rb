class SitemapsController < ActionController::Base
  def show
    xml = Sitemap::Renderer.call

    expires_in 1.hour, public: true if Rails.env.production?
    render body: xml, content_type: "application/xml", layout: false
  end
end
