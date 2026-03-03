SitemapGenerator::Sitemap.default_host = ENV.fetch("APP_HOST", "https://canine.sh")

SitemapGenerator::Sitemap.create do
  add "/", priority: 1.0, changefreq: "weekly"
  add "/privacy", priority: 0.3, changefreq: "monthly"
  add "/terms", priority: 0.3, changefreq: "monthly"
  add "/calculator", priority: 0.5, changefreq: "monthly"
end
