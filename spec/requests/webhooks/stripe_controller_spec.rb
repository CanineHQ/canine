# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Webhooks::StripeController, type: :request do
  let(:account) { create(:account) }
  let(:webhook_secret) { "whsec_test_secret" }

  before do
    allow(Rails.configuration).to receive(:cloud_mode).and_return(true)
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with("STRIPE_WEBHOOK_SECRET").and_return(webhook_secret)
  end

  def post_webhook(event_type, data, metadata: {})
    payload = { type: event_type, data: { object: data.merge(metadata: metadata) } }.to_json
    timestamp = Time.now
    signature = Stripe::Webhook::Signature.compute_signature(timestamp, payload, webhook_secret)
    sig_header = "t=#{timestamp.to_i},v1=#{signature}"

    post "/webhooks/stripe", params: payload, headers: {
      "CONTENT_TYPE" => "application/json",
      "HTTP_STRIPE_SIGNATURE" => sig_header
    }
  end

  describe "checkout.session.completed" do
    it "upgrades account to pro with subscription details" do
      subscription = OpenStruct.new(id: "sub_123", status: "active", trial_end: nil)
      allow(Stripe::Subscription).to receive(:retrieve).with("sub_123").and_return(subscription)

      post_webhook("checkout.session.completed",
        { subscription: "sub_123" },
        metadata: { "account_id" => account.id.to_s })

      expect(response).to have_http_status(:ok)
      account.reload
      expect(account.plan).to eq("pro")
      expect(account.stripe_subscription_id).to eq("sub_123")
      expect(account.subscription_status).to eq("active")
    end

    it "ignores unknown account" do
      subscription = OpenStruct.new(id: "sub_123", status: "active", trial_end: nil)
      allow(Stripe::Subscription).to receive(:retrieve).with("sub_123").and_return(subscription)

      post_webhook("checkout.session.completed",
        { subscription: "sub_123" },
        metadata: { "account_id" => "999999" })

      expect(response).to have_http_status(:ok)
    end
  end

  describe "customer.subscription.updated" do
    it "updates subscription status" do
      account.update!(stripe_subscription_id: "sub_123", plan: :pro, subscription_status: "active")

      post_webhook("customer.subscription.updated", { id: "sub_123", status: "past_due" })

      expect(response).to have_http_status(:ok)
      expect(account.reload.subscription_status).to eq("past_due")
    end
  end

  describe "customer.subscription.deleted" do
    it "downgrades account to free" do
      account.update!(stripe_subscription_id: "sub_123", plan: :pro, subscription_status: "active")

      post_webhook("customer.subscription.deleted", { id: "sub_123" })

      expect(response).to have_http_status(:ok)
      account.reload
      expect(account.plan).to eq("free")
      expect(account.subscription_status).to eq("canceled")
      expect(account.stripe_subscription_id).to be_nil
    end
  end

  describe "signature verification" do
    it "returns bad_request with invalid signature" do
      post "/webhooks/stripe", params: { type: "test" }.to_json, headers: {
        "CONTENT_TYPE" => "application/json",
        "HTTP_STRIPE_SIGNATURE" => "t=123,v1=invalid"
      }

      expect(response).to have_http_status(:bad_request)
    end
  end

  describe "cloud_mode guard" do
    it "returns not_found when not in cloud mode" do
      allow(Rails.configuration).to receive(:cloud_mode).and_return(false)

      post "/webhooks/stripe", params: {}.to_json, headers: { "CONTENT_TYPE" => "application/json" }

      expect(response).to have_http_status(:not_found)
    end
  end
end
