class SitemapsController < ApplicationController
  def show
    @entries = Sitemap::Builder.new.entries
    expires_in 1.hour, public: true if Rails.env.production?
  end
end
