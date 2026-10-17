require "rails_helper"

RSpec.describe "MCP", type: :request do
  let(:account_user) { create(:account_user, role: :member) }
  let(:user) { account_user.user }
  let(:application) { Doorkeeper::Application.create!(name: "client", redirect_uri: "https://client.example/callback", scopes: "public read write openid profile email") }

  def mcp(token, method, params = {})
    post "/mcp", params: { jsonrpc: "2.0", id: 1, method:, params: }.to_json,
      headers: { "Authorization" => "Bearer #{token.plaintext_token || token.token}", "Content-Type" => "application/json" }
    response.parsed_body
  end

  def token(scopes)
    Doorkeeper::AccessToken.create!(application:, resource_owner_id: user.id, scopes:)
  end

  it "accepts tokens from the MCP sign-in flow, rejects internal SSO tokens, and serves tools and resources" do
    post "/mcp", params: { jsonrpc: "2.0", id: 1, method: "tools/list" }.to_json, headers: { "Content-Type" => "application/json" }
    expect(response).to have_http_status(:unauthorized)

    # Internal SSO tokens (the auth proxies in front of deployed apps) only identify the user.
    mcp(token("openid profile email"), "tools/list")
    expect(response).to have_http_status(:forbidden)

    # Clients such as Claude Code request no scope, so their tokens carry only the default public scope.
    api = token("public")
    expect(mcp(api, "initialize", protocolVersion: "2025-06-18", capabilities: {}, clientInfo: { name: "spec", version: "1" })
      .dig("result", "serverInfo", "name")).to eq("canine_mcp_server")
    expect(mcp(api, "tools/list").dig("result", "tools").map { |tool| tool["name"] }).to include("update_project", "get_error_issue")
    expect(mcp(api, "resources/read", uri: "canine://accounts").dig("result", "contents", 0, "text")).to include(account_user.account.name)

    project = create(:project, cluster: create(:cluster, account: account_user.account), account: account_user.account)
    build = create(:build, project:)
    builds = mcp(api, "resources/read", uri: "canine://accounts/#{account_user.account.id}/projects/#{project.id}/builds")
    expect(JSON.parse(builds.dig("result", "contents", 0, "text")).map { |b| b["id"] }).to eq([ build.id ])
  end

  it "only hands out kubeconfigs for clusters the user's teams can reach" do
    account = account_user.account
    visible, hidden = create_list(:cluster, 2, account:)
    team = create(:team, account:)
    create(:team_membership, team:, user:)
    create(:team_resource, team:, resourceable: visible)

    call = ->(cluster) { mcp(token("public read write"), "tools/call", name: "get_cluster_kubeconfig", arguments: { cluster_id: cluster.id }).dig("result") }
    expect(call.(visible)["isError"]).to be_falsey
    expect(call.(hidden)).to include("isError" => true)
    clusters = mcp(token("public read write"), "resources/read", uri: "canine://accounts/#{account.id}/clusters").dig("result", "contents", 0, "text")
    expect(JSON.parse(clusters).map { |cluster| cluster["id"] }).to eq([ visible.id ])
  end
end
