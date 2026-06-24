module Sitemap
  class Builder
    include Rails.application.routes.url_helpers

    Entry = Data.define(:loc, :lastmod, :changefreq, :priority)

    def entries
      static_entries + blog_entries + product_entries
    end

    def default_url_options
      {
        host: ENV.fetch("APP_HOST", "removlo.co.uk"),
        protocol: ENV.fetch("APP_PROTOCOL", Rails.env.production? ? "https" : "http")
      }
    end

    private

    def static_entries
      [
        entry(root_url, changefreq: "weekly", priority: "1.0"),
        entry(get_quotation_url, changefreq: "weekly", priority: "0.95"),
        entry(services_url, changefreq: "monthly", priority: "0.9"),
        entry(home_removals_url, changefreq: "monthly", priority: "0.85"),
        entry(office_removals_url, changefreq: "monthly", priority: "0.85"),
        entry(packing_services_url, changefreq: "monthly", priority: "0.85"),
        entry(storage_solutions_url, changefreq: "monthly", priority: "0.85"),
        entry(how_it_works_url, changefreq: "monthly", priority: "0.8"),
        entry(about_url, changefreq: "monthly", priority: "0.75"),
        entry(reviews_url, changefreq: "weekly", priority: "0.75"),
        entry(contact_url, changefreq: "monthly", priority: "0.75"),
        entry(blog_posts_url, changefreq: "weekly", priority: "0.8"),
        entry(shop_products_url, changefreq: "weekly", priority: "0.8")
      ]
    end

    def blog_entries
      BlogPost.published.pluck(:slug, :updated_at, :published_at).map do |slug, updated_at, published_at|
        entry(
          blog_post_url(slug),
          lastmod: updated_at || published_at,
          changefreq: "monthly",
          priority: "0.7"
        )
      end
    end

    def product_entries
      Product.catalog.pluck(:slug, :updated_at).map do |slug, updated_at|
        entry(
          shop_product_url(slug),
          lastmod: updated_at,
          changefreq: "weekly",
          priority: "0.7"
        )
      end
    end

    def entry(loc, lastmod: nil, changefreq: nil, priority: nil)
      Entry.new(
        loc: loc,
        lastmod: format_lastmod(lastmod),
        changefreq: changefreq,
        priority: priority
      )
    end

    def format_lastmod(timestamp)
      return if timestamp.blank?

      timestamp.utc.iso8601
    end
  end
end
