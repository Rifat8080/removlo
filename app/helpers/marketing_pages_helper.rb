module MarketingPagesHelper
  def marketing_asset_image(file)
    "images/#{file}"
  end

  def marketing_picture_image(file, **image_options)
    return image_tag(marketing_asset_image(file), **image_options) unless file.to_s.end_with?(".png")

    content_tag(:picture, class: "contents") do
      safe_join(
        [
          tag.source(srcset: asset_path(marketing_asset_image(file.sub(/\.png\z/, ".webp"))), type: "image/webp"),
          image_tag(marketing_asset_image(file), **image_options)
        ]
      )
    end
  end

  def marketing_nav_links
    [
      ["Home", root_path],
      ["Services", services_path],
      ["How it works", how_it_works_path],
      ["About us", about_path],
      ["Reviews", reviews_path],
      ["Resources", blog_posts_path],
      ["Shop", shop_products_path],
      ["Contact", contact_path]
    ]
  end

  def marketing_quote_path
    get_quotation_path
  end

  def marketing_service_cards
    [
      { title: "Home Removals", description: "From flats to family homes, we move it all.", icon: "home_removals_icon.svg", image: "home_removals_image.png", path: home_removals_path },
      { title: "Office Removals", description: "Minimise downtime with our efficient service.", icon: "office_removals_icon.svg", image: "office_removals_image.png", path: office_removals_path },
      { title: "Packing Services", description: "Professional packing for a stress-free move.", icon: "packing_services_icon.svg", image: "packing_services_image.png", path: packing_services_path },
      { title: "Storage Solutions", description: "Secure short or long-term storage options.", icon: "storage_solutions_icon.svg", image: "storage_solutions_image.png", path: storage_solutions_path }
    ]
  end

  def marketing_reviews
    [
      { name: "Sarah T.", route: "London to Manchester", quote: "Removlo made our move go from stressful to simple. The team was professional, careful, and friendly." },
      { name: "James R.", route: "Office relocation", quote: "Clear quote, punctual crew, and great communication. We were working again the next morning." },
      { name: "Amina K.", route: "Packing and storage", quote: "The packing team labelled everything beautifully and kept fragile items safe from start to finish." },
      { name: "David P.", route: "Bristol to Cardiff", quote: "Transparent pricing and live updates made this the smoothest move we've ever had." },
      { name: "Emma L.", route: "Studio flat move", quote: "Quick quote, friendly crew, and no hidden extras. Would recommend to anyone moving in the UK." }
    ]
  end

  def marketing_benefits
    [
      ["Real-time tracking", "Know your route, ETA, and crew status.", "route-tracking.svg"],
      ["Dedicated support", "One friendly coordinator from quote to keys.", "headset-support.svg"],
      ["Care & protection", "Careful crews, insurance options, and item notes.", "shield-protection.svg"],
      ["Transparent pricing", "No surprises, no pressure, no hidden extras.", "price-receipt.svg"]
    ]
  end

  def marketing_how_it_works_steps
    [
      ["Set your quote", "Tell us the basics and get an instant price.", "quote-document.svg"],
      ["Book your move", "Pick a date that suits you. We'll handle the rest.", "calendar-check.svg"],
      ["We move you", "Sit back while our team moves you smoothly.", "moving-truck.svg"]
    ]
  end

  def marketing_footer_columns
    [
      ["Services", [
        ["Home Removals", home_removals_path],
        ["Office Removals", office_removals_path],
        ["Packing Services", packing_services_path],
        ["Storage Solutions", storage_solutions_path]
      ]],
      ["Company", [
        ["About us", about_path],
        ["Why Removlo?", about_path],
        ["Our team", "#{about_path}#team"],
        ["Careers", contact_path]
      ]],
      ["Support", [
        ["Contact us", contact_path],
        ["Help centre", contact_path],
        ["FAQs", "#{root_path}#faq"],
        ["Moving guides", blog_posts_path]
      ]],
      ["Resources", [
        ["Moving checklist", blog_posts_path],
        ["Packing tips", packing_services_path],
        ["Storage guide", storage_solutions_path],
        ["Blog", blog_posts_path]
      ]],
      ["Contact", [
        ["020 7946 0958", "tel:02079460958"],
        ["hello@removlo.com", "mailto:hello@removlo.com"],
        ["UK-wide coverage", services_path],
        ["Mon-Fri, 8am-8pm", contact_path]
      ]]
    ]
  end
end
