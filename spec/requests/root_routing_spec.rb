require "rails_helper"

RSpec.describe "Root routing", type: :request do
  around do |example|
    config = Rails.application.config
    original_local_mode = config.local_mode
    original_cluster_mode = config.cluster_mode
    original_onboarding_methods = config.onboarding_methods

    config.local_mode = false
    config.cluster_mode = true
    config.onboarding_methods = []
    Rails.application.reload_routes!

    example.run
  ensure
    config.local_mode = original_local_mode
    config.cluster_mode = original_cluster_mode
    config.onboarding_methods = original_onboarding_methods
    Rails.application.reload_routes!
  end

  it "renders onboarding in cluster mode without onboarding methods configured" do
    get "/"

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Select your installation method")
  end
end
