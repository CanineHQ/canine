# frozen_string_literal: true

require "rails_helper"

RSpec.describe InboundWebhooks::BitbucketController, type: :request do
  let(:webhook_secret) { "test_bitbucket_secret" }
  let(:payload) { { push: { changes: [{ new: { name: "main" } }] } }.to_json }

  before do
    stub_const("Git::Bitbucket::Client::BITBUCKET_WEBHOOK_SECRET", webhook_secret)
  end

  def sign(payload, secret)
    "sha256=" + OpenSSL::HMAC.hexdigest(OpenSSL::Digest.new("sha256"), secret, payload)
  end

  describe "signature verification" do
    it "accepts a valid signature and creates an inbound webhook" do
      expect {
        post "/inbound_webhooks/bitbucket", params: payload, headers: {
          "CONTENT_TYPE" => "application/json",
          "X-Hub-Signature" => sign(payload, webhook_secret)
        }
      }.to change(InboundWebhook, :count).by(1)

      expect(response).to have_http_status(:ok)
    end

    it "rejects an invalid signature" do
      post "/inbound_webhooks/bitbucket", params: payload, headers: {
        "CONTENT_TYPE" => "application/json",
        "X-Hub-Signature" => "sha256=invalid"
      }

      expect(response).to have_http_status(:bad_request)
    end

    it "rejects when signature header is missing" do
      post "/inbound_webhooks/bitbucket", params: payload, headers: {
        "CONTENT_TYPE" => "application/json"
      }

      expect(response).to have_http_status(:bad_request)
    end

    it "rejects when secret is not configured" do
      stub_const("Git::Bitbucket::Client::BITBUCKET_WEBHOOK_SECRET", nil)

      post "/inbound_webhooks/bitbucket", params: payload, headers: {
        "CONTENT_TYPE" => "application/json",
        "X-Hub-Signature" => sign(payload, "anything")
      }

      expect(response).to have_http_status(:bad_request)
    end
  end
end
