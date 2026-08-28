if Rails.configuration.cloud_mode
  Stripe.api_key = ENV["STRIPE_SECRET_KEY"]
  Stripe.api_version = "2025-03-31.basil"
end
