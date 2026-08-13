SitemapGenerator::Sitemap.default_host = ENV.fetch("APP_HOST", "https://canine.sh")
SitemapGenerator::Sitemap.compress = false

SitemapGenerator::Sitemap.create do
  add "/", priority: 1.0, changefreq: "weekly"
  add "/privacy", priority: 0.3, changefreq: "monthly"
  add "/terms", priority: 0.3, changefreq: "monthly"
  add "/calculator", priority: 0.5, changefreq: "monthly"
  add "/self-hosted", priority: 0.7, changefreq: "monthly"
  add "/model-context-protocol", priority: 0.5, changefreq: "monthly"
  add "/workbench", priority: 0.5, changefreq: "monthly"
  add "/api-docs", priority: 0.5, changefreq: "monthly"
  add "/llms.txt", priority: 0.3, changefreq: "monthly"
end
