namespace :sitemap do
  desc "Generate public/sitemap.xml for crawlers and static file serving"
  task refresh: :environment do
    path = Rails.root.join("public/sitemap.xml")
    xml = Sitemap::Renderer.call
    File.write(path, xml)

    puts "Wrote #{path} (#{xml.scan('<loc>').size} URLs)"
  end
end
