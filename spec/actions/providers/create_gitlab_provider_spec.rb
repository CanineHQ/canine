require 'webmock/rspec'
require 'rails_helper'

RSpec.describe Providers::CreateGitlabProvider do
  let(:provider) { build(:provider, :gitlab) }
  let(:subject) { described_class.execute(provider: provider) }
  let(:personal_access_tokens_data) do
    JSON.parse(File.read(Rails.root.join('spec/resources/integrations/gitlab/personal_access_tokens.json')))
  end

  let(:user_data) do
    JSON.parse(File.read(Rails.root.join('spec/resources/integrations/gitlab/user.json')))
  end

  describe '.execute' do
    context 'when the access token is valid and has correct scopes' do
      before do
        stub_request(:get, Providers::CreateGitlabProvider::GITLAB_PAT_API_URL)
          .to_return(
            status: 200,
            body: personal_access_tokens_data.to_json,
            headers: { 'Content-Type' => 'application/json' }
          )
        stub_request(:get, Providers::CreateGitlabProvider::GITLAB_USER_API_URL)
          .to_return(
            status: 200,
            body: user_data.to_json,
            headers: { 'Content-Type' => 'application/json' }
          )
      end

      it 'saves the provider' do
        expect(subject).to be_success
        expect(JSON.parse(subject.provider.auth)["info"]["nickname"]).to eq("czhu12")
        expect(subject.provider).to be_persisted
      end
    end

    context 'when the access token is invalid' do
      before do
        stub_request(:get, Providers::CreateGitlabProvider::GITLAB_PAT_API_URL)
          .to_return(
            status: 401,
            body: { error: "Unauthorized" }.to_json,
            headers: { 'Content-Type' => 'application/json' }
          )
      end
      it 'fails the context with an invalid token message' do
        expect(subject).to be_failure
        expect(subject.message).to eq("Invalid access token")
      end

      it 'adds an error to the provider' do
        subject
        expect(provider.errors[:access_token]).to include("Invalid access token")
      end
    end

    context 'when the scopes are invalid' do
      before do
        error_response = personal_access_tokens_data.deep_dup
        error_response["scopes"] = []
        stub_request(:get, Providers::CreateGitlabProvider::GITLAB_PAT_API_URL)
          .to_return(
            status: 200,
            body: error_response.to_json,
            headers: { 'Content-Type' => 'application/json' }
          )
      end

      it 'fails the context with an invalid scopes message' do
        expect(subject).to be_failure
        expect(subject.message).to include("Invalid scopes")
        expect(subject.message).to include("read_repository, read_registry, write_registry")
      end
    end
  end
end
