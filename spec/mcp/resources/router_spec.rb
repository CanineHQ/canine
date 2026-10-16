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

  it "lists only MCP-enabled accounts, with the clusters and counts the user's teams can see" do
    account = account_user.account
    hidden = create(:cluster, account:)
    team = create(:team, account:)
    create(:team_membership, team:, user:)
    create(:team_resource, team:, resourceable: project.cluster)
    create(:account_user, user:, account: create(:account, allow_mcp: false))

    accounts = JSON.parse(described_class.call("canine://accounts", server_context).first[:text])
    expect(accounts.map { |a| a["id"] }).to eq([ account.id ])
    expect(accounts.first["clusters"].map { |c| c["id"] }).to eq([ project.cluster.id ])
    expect(accounts.first["clusters"].first["projects_count"]).to eq(1)
    expect(accounts.first["totals"]).to include("clusters" => 1, "projects" => 1)
    expect(hidden).to be_persisted
  end

  it "routes canine://accounts/{account_id}/projects/{project_id}/builds/{build_id}" do
    build = create(:build, project:)
    result = described_class.call("canine://accounts/#{account_user.account.id}/projects/#{project.id}/builds/#{build.id}", server_context)
    expect(JSON.parse(result.first[:text])["id"]).to eq(build.id)
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
