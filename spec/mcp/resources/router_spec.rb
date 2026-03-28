# frozen_string_literal: true

require "rails_helper"

RSpec.describe Resources::Router do
  let(:project) { create(:project) }
  let(:user) { create(:user) }
  let(:account_user) { create(:account_user, account: project.account, user: user) }
  let(:server_context) { { user_id: user.id } }

  before { account_user }

  it "routes canine://accounts" do
    result = described_class.call("canine://accounts", server_context)
    expect(result.first[:mimeType]).to eq("application/json")
  end

  it "routes canine://providers" do
    result = described_class.call("canine://providers", server_context)
    expect(result.first[:mimeType]).to eq("application/json")
  end

  it "routes canine://accounts/{account_id}/clusters" do
    result = described_class.call("canine://accounts/#{account_user.account.id}/clusters", server_context)
    expect(result.first[:mimeType]).to eq("application/json")
  end

  it "routes canine://accounts/{account_id}/projects" do
    result = described_class.call("canine://accounts/#{account_user.account.id}/projects", server_context)
    expect(result.first[:mimeType]).to eq("application/json")
  end

  it "routes canine://accounts/{account_id}/projects/{project_id}" do
    result = described_class.call("canine://accounts/#{account_user.account.id}/projects/#{project.id}", server_context)
    expect(result.first[:mimeType]).to eq("application/json")
  end

  it "routes canine://accounts/{account_id}/add_ons" do
    result = described_class.call("canine://accounts/#{account_user.account.id}/add_ons", server_context)
    expect(result.first[:mimeType]).to eq("application/json")
  end

  it "returns account access denied for unknown account_id" do
    result = described_class.call("canine://accounts/0/projects", server_context)
    expect(result.first[:mimeType]).to eq("text/plain")
    expect(result.first[:text]).to eq("Account not found or access denied")
  end

  it "returns unknown resource for unmatched URIs" do
    result = described_class.call("canine://does_not_exist", server_context)
    expect(result.first[:mimeType]).to eq("text/plain")
    expect(result.first[:text]).to eq("Unknown resource")
  end
end
