# frozen_string_literal: true

require "rails_helper"

RSpec.describe InboundWebhooks::GitlabController, type: :request do
  let(:webhook_secret) { "test_gitlab_secret" }
  let(:payload) { { ref: "refs/heads/main", project: { path_with_namespace: "org/repo" } }.to_json }

  before do
    stub_const("Git::Gitlab::Client::GITLAB_WEBHOOK_SECRET", webhook_secret)
  end

  describe "signature verification" do
    it "accepts a valid token and creates an inbound webhook" do
      expect {
        post "/inbound_webhooks/gitlab", params: payload, headers: {
          "CONTENT_TYPE" => "application/json",
          "X-Gitlab-Token" => webhook_secret
        }
      }.to change(InboundWebhook, :count).by(1)

      expect(response).to have_http_status(:ok)
    end

    it "rejects an invalid token" do
      post "/inbound_webhooks/gitlab", params: payload, headers: {
        "CONTENT_TYPE" => "application/json",
        "X-Gitlab-Token" => "wrong_token"
      }

      expect(response).to have_http_status(:bad_request)
    end

    it "rejects when token header is missing" do
      post "/inbound_webhooks/gitlab", params: payload, headers: {
        "CONTENT_TYPE" => "application/json"
      }

      expect(response).to have_http_status(:bad_request)
    end

    it "rejects when secret is not configured" do
      stub_const("Git::Gitlab::Client::GITLAB_WEBHOOK_SECRET", nil)

      post "/inbound_webhooks/gitlab", params: payload, headers: {
        "CONTENT_TYPE" => "application/json",
        "X-Gitlab-Token" => "anything"
      }

      expect(response).to have_http_status(:bad_request)
    end
  end
end
