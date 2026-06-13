# Be sure to restart your server when you modify this file.

# Version of your assets, change this if you want to expire all your assets.
Rails.application.config.assets.version = "1.0"

# Add additional assets to the asset load path.
# Rails.application.config.assets.paths << Emoji.images_path
Rails.application.config.assets.paths << Rails.root.join("app/assets")

# Propshaft uses MIME extension lookups when resolving assets.
Mime::Type.register "image/webp", :webp unless Mime::Type.lookup_by_extension(:webp)
