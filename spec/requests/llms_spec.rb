# frozen_string_literal: true

require 'rails_helper'

RSpec.describe "llms.txt", type: :request do
  it "serves an agent guide pointing at this instance's API" do
    get "/llms.txt"

    expect(response).to have_http_status(:ok)
    expect(response.media_type).to eq("text/plain")
    expect(response.body).to start_with("# Canine")
    expect(response.body).to include("http://www.example.com/api/v1")
    expect(response.body).to include("X-API-Key")
  end

  it "accepts the API key as a bearer token" do
    api_token = create(:api_token)
    create(:account_user, user: api_token.user)

    get "/api/v1/me", headers: { "Authorization" => "Bearer #{api_token.access_token}" }

    expect(response).to have_http_status(:ok)
  end
end
