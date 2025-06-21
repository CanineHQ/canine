require 'rails_helper'

RSpec.describe Git::Gitlab::Client do
  let(:access_token) { 'test_token' }
  let(:repository_url) { 'czhu12/echo' }
  let(:client) { described_class.new(access_token:, repository_url:) }

  describe '#register_webhook!' do
    let(:webhook_url) { 'http://localhost:3000/inbound_webhooks/gitlab' }
    let(:success_response) { double('response', success?: true, parsed_response: { 'id' => 1 }) }
    let(:failure_response) { double('response', success?: false, body: 'Error message') }

    before do
      allow(Rails.application.routes.url_helpers).to receive(:inbound_webhooks_gitlab_index_url).and_return(webhook_url)
    end

    context 'when webhook already exists' do
      before do
        allow(client).to receive(:webhook_exists?).and_return(true)
      end

      it 'returns early without creating webhook' do
        expect(HTTParty).not_to receive(:post)
        client.register_webhook!
      end
    end

    context 'when webhook does not exist' do
      before do
        allow(client).to receive(:webhook_exists?).and_return(false)
      end

      it 'creates a new webhook' do
        expect(HTTParty).to receive(:post).with(
          "#{described_class::GITLAB_API_BASE}/projects/#{client.encoded_url}/hooks",
          headers: { "Authorization" => "Bearer #{access_token}", "Content-Type" => "application/json" },
          body: {
            url: webhook_url,
            name: "canine-webhook",
            push_events: true,
            enable_ssl_verification: true,
            token: described_class::GITLAB_WEBHOOK_SECRET
          }.to_json
        ).and_return(success_response)

        client.register_webhook!
      end

      context 'when webhook creation fails' do
        it 'raises an error' do
          expect(HTTParty).to receive(:post).and_return(failure_response)
          expect { client.register_webhook! }.to raise_error('Failed to register webhook: Error message')
        end
      end
    end
  end

  describe '#remove_webhook!' do
    let(:webhook) { { 'id' => 1 } }

    context 'when webhook exists' do
      before do
        allow(client).to receive(:webhook_exists?).and_return(true)
        allow(client).to receive(:webhook).and_return(webhook)
      end

      it 'deletes the webhook' do
        expect(HTTParty).to receive(:delete).with(
          "#{described_class::GITLAB_API_BASE}/projects/#{client.encoded_url}/hooks/#{webhook['id']}",
          headers: { "Authorization" => "Bearer #{access_token}" }
        )

        client.remove_webhook!
      end
    end

    context 'when webhook does not exist' do
      before do
        allow(client).to receive(:webhook_exists?).and_return(false)
      end

      it 'does not make delete request' do
        expect(HTTParty).not_to receive(:delete)
        client.remove_webhook!
      end
    end
  end
end
