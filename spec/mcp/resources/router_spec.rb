# frozen_string_literal: true

require "rails_helper"

RSpec.describe Resources::Router do
  let(:project) { create(:project) }
  let(:user) { create(:user) }
  let(:server_context) { { user_id: user.id } }

  before { create(:account_user, account: project.account, user: user) }

  it "routes canine://accounts" do
    result = described_class.call("canine://accounts", server_context)
    expect(result.first[:mimeType]).to eq("application/json")
  end

  it "routes canine://providers" do
    result = described_class.call("canine://providers", server_context)
    expect(result.first[:mimeType]).to eq("application/json")
  end

  it "routes canine://clusters" do
    result = described_class.call("canine://clusters", server_context)
    expect(result.first[:mimeType]).to eq("application/json")
  end

  it "routes canine://projects" do
    result = described_class.call("canine://projects", server_context)
    expect(result.first[:mimeType]).to eq("application/json")
  end

  it "routes canine://projects/{id}" do
    result = described_class.call("canine://projects/#{project.id}", server_context)
    expect(result.first[:mimeType]).to eq("application/json")
  end

  it "routes canine://add_ons" do
    result = described_class.call("canine://add_ons", server_context)
    expect(result.first[:mimeType]).to eq("application/json")
  end

  it "returns unknown resource for unmatched URIs" do
    result = described_class.call("canine://does_not_exist", server_context)
    expect(result.first[:mimeType]).to eq("text/plain")
    expect(result.first[:text]).to eq("Unknown resource")
  end
end
