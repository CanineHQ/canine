# frozen_string_literal: true

require "rails_helper"

RSpec.describe InboundWebhooks::GithubController, type: :request do
  let(:webhook_secret) { "test_github_secret" }
  let(:payload) { { ref: "refs/heads/main", repository: { full_name: "org/repo" } }.to_json }

  before do
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with("OMNIAUTH_GITHUB_WEBHOOK_SECRET").and_return(webhook_secret)
  end

  def sign(payload, secret)
    "sha256=" + OpenSSL::HMAC.hexdigest(OpenSSL::Digest.new("sha256"), secret, payload)
  end

  describe "signature verification" do
    it "accepts a valid signature and creates an inbound webhook" do
      expect {
        post "/inbound_webhooks/github", params: payload, headers: {
          "CONTENT_TYPE" => "application/json",
          "HTTP_X_HUB_SIGNATURE_256" => sign(payload, webhook_secret)
        }
      }.to change(InboundWebhook, :count).by(1)

      expect(response).to have_http_status(:ok)
    end

    it "rejects an invalid signature" do
      post "/inbound_webhooks/github", params: payload, headers: {
        "CONTENT_TYPE" => "application/json",
        "HTTP_X_HUB_SIGNATURE_256" => "sha256=invalid"
      }

      expect(response).to have_http_status(:bad_request)
    end

    it "rejects when signature header is missing" do
      post "/inbound_webhooks/github", params: payload, headers: {
        "CONTENT_TYPE" => "application/json"
      }

      expect(response).to have_http_status(:bad_request)
    end

    it "rejects when secret is not configured" do
      allow(ENV).to receive(:[]).with("OMNIAUTH_GITHUB_WEBHOOK_SECRET").and_return(nil)

      post "/inbound_webhooks/github", params: payload, headers: {
        "CONTENT_TYPE" => "application/json",
        "HTTP_X_HUB_SIGNATURE_256" => sign(payload, "anything")
      }

      expect(response).to have_http_status(:bad_request)
    end
  end
end
