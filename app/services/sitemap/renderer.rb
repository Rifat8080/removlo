module Sitemap
  class Renderer
    def self.call
      new.call
    end

    def call
      ApplicationController.renderer.render(
        template: "sitemaps/show",
        formats: [:xml],
        handlers: [:builder],
        assigns: { entries: Builder.new.entries }
      )
    end
  end
end
