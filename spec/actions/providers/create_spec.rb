require 'rails_helper'

RSpec.describe Providers::Create do
  let(:subject) { described_class.call(provider) }

  describe '.call' do
    context 'when the provider is container registry' do
      let(:provider) { build(:provider, :container_registry) }

      before do
        # Mock successful Docker authentication
        allow(DockerCli).to receive(:with_registry_auth).and_yield
      end

      it 'creates the provider' do
        subject
        expect(subject).to be_success
      end
    end

    context 'when the provider is github' do
      let(:provider) { build(:provider, :github) }
      context 'when the access token is valid' do
        before do
          allow(Octokit::Client).to receive(:new).and_return(double(user: { login: 'test_user' }, scopes: [ 'repo', 'write:packages' ]))
        end

        it 'sets the provider auth info' do
          subject
          expect(provider.auth).to include('nickname')
        end

        it 'saves the provider' do
          expect(subject.provider).to be_persisted
        end
      end

      context 'when the access token is invalid' do
        before do
          allow(Octokit::Client).to receive(:new).and_raise(Octokit::Unauthorized)
        end

        it 'adds an error to the provider' do
          subject
          expect(provider.errors[:access_token]).to include("Invalid access token")
        end
      end

      context 'when the scopes are invalid' do
        before do
          allow(Octokit::Client).to receive(:new).and_return(double(user: { login: 'test_user' }, scopes: [ 'repo' ]))
        end

        it 'fails the context with an invalid scopes message' do
          subject
          expect(subject).to be_failure
        end
      end
    end
  end
end
