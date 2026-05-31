module Shop
  class SeedCatalog
    CATEGORIES = [
      { name: "Boxes", slug: "boxes", position: 1 },
      { name: "Tape & wrap", slug: "tape-wrap", position: 2 },
      { name: "Protection", slug: "protection", position: 3 },
      { name: "Moving kits", slug: "moving-kits", position: 4 }
    ].freeze

    PRODUCTS = [
      { category: "boxes", name: "Small moving box", sku: "BOX-SM", price_cents: 250, stock: 200, featured: true },
      { category: "boxes", name: "Medium moving box", sku: "BOX-MD", price_cents: 350, stock: 150, featured: true },
      { category: "boxes", name: "Large moving box", sku: "BOX-LG", price_cents: 450, stock: 120 },
      { category: "tape-wrap", name: "Packing tape roll", sku: "TAPE-01", price_cents: 399, stock: 300, featured: true },
      { category: "tape-wrap", name: "Bubble wrap roll", sku: "BUBBLE-01", price_cents: 1299, stock: 80 },
      { category: "protection", name: "Furniture cover", sku: "COVER-01", price_cents: 899, stock: 60 },
      { category: "protection", name: "Mattress bag", sku: "BAG-MAT", price_cents: 599, stock: 90 },
      { category: "moving-kits", name: "Studio moving kit", sku: "KIT-STUDIO", price_cents: 2999, stock: 40, featured: true }
    ].freeze

    def self.call
      CATEGORIES.each do |attrs|
        ProductCategory.find_or_create_by!(slug: attrs[:slug]) do |category|
          category.assign_attributes(attrs)
        end
      end

      PRODUCTS.each do |attrs|
        category = ProductCategory.find_by!(slug: attrs[:category])
        product = Product.find_or_initialize_by(sku: attrs[:sku])
        product.assign_attributes(
          product_category: category,
          name: attrs[:name],
          slug: attrs[:name].parameterize,
          description: "Quality #{attrs[:name].downcase} for your move.",
          price_cents: attrs[:price_cents],
          stock_quantity: attrs[:stock],
          featured: attrs[:featured] || false,
          status: :active
        )
        product.save!
      end
    end
  end
end
