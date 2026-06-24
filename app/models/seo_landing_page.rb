class SeoLandingPage
  Page = Data.define(
    :slug,
    :keyword,
    :title,
    :meta_description,
    :hero_lead,
    :hero_highlight,
    :hero_subtitle,
    :structured_description
  )

  KEYWORDS = [
    "removal company near me",
    "removals near me",
    "house removals near me",
    "man and van near me",
    "man with a van near me",
    "local removal company",
    "house removal company",
    "home removals company",
    "moving company near me",
    "local movers near me",
    "affordable removals near me",
    "cheap removals near me",
    "same day removals",
    "last minute removals",
    "removal quote online",
    "get removal quote",
    "book removal company online",
    "house removal quote",
    "moving house quote",
    "removals cost UK",
    "house removal costs UK",
    "how much do removals cost",
    "removal company prices",
    "man and van prices",
    "cheap man and van near me",
    "small removals near me",
    "flat removals near me",
    "apartment removals",
    "student removals",
    "furniture removals near me",
    "sofa removal service",
    "single item removals",
    "piano removals near me",
    "office removals near me",
    "commercial removals",
    "business relocation services",
    "packing and moving services",
    "removals and storage",
    "storage and removals near me",
    "long distance removals UK",
    "national removals UK",
    "UK wide removals",
    "moving from London to Manchester",
    "moving from London to Birmingham",
    "moving from London to Leeds",
    "removals London",
    "removal company London",
    "man and van London",
    "house removals London",
    "removals Manchester",
    "removal company Manchester",
    "removals Birmingham",
    "removal company Birmingham",
    "removals Leeds",
    "removals Liverpool",
    "removals Bristol",
    "removals Sheffield",
    "removals Nottingham",
    "removals Leicester",
    "removals Southampton"
  ].freeze

  class << self
    def all
      @all ||= KEYWORDS.map { |keyword| build(keyword) }
    end

    def find(slug)
      index[slug.to_s]
    end

    def find!(slug)
      find(slug) || raise(ActiveRecord::RecordNotFound)
    end

    def valid_slug?(slug)
      index.key?(slug.to_s)
    end

    def slugs
      index.keys
    end

    private

    def index
      @index ||= all.index_by(&:slug)
    end

    def build(keyword)
      label = keyword.titleize
      slug = keyword.parameterize

      Page.new(
        slug: slug,
        keyword: keyword,
        title: "Removlo — #{label} | UK Removals",
        meta_description: meta_description_for(keyword, label),
        hero_lead: "#{label},",
        hero_highlight: "made smart",
        hero_subtitle: hero_subtitle_for(keyword, label),
        structured_description: structured_description_for(keyword, label)
      )
    end

    def meta_description_for(keyword, label)
      if keyword.include?("cost") || keyword.include?("price") || keyword.include?("quote")
        "Compare #{label.downcase} with Removlo. Get transparent UK removal pricing, online quotes, careful crews, and live move tracking from a trusted removals team."
      elsif keyword.match?(/London|Manchester|Birmingham|Leeds|Liverpool|Bristol|Sheffield|Nottingham|Leicester|Southampton/)
        "Book #{label.downcase} with Removlo. Transparent quotes, professional movers, packing options, and live tracking for local and UK-wide house removals."
      else
        "Searching for #{label.downcase}? Removlo offers transparent quotes, careful crews, packing options, and live tracking for house removals across the UK."
      end
    end

    def hero_subtitle_for(keyword, label)
      "Removlo helps customers looking for #{label.downcase} with transparent quotes, dedicated coordinators, and live move tracking from pickup to delivery."
    end

    def structured_description_for(keyword, label)
      "Removlo provides #{label.downcase} with transparent online quotes, professional crews, packing and storage options, and live move tracking across the United Kingdom."
    end
  end
end
