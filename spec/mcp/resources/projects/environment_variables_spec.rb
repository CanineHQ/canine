# frozen_string_literal: true

require "rails_helper"

RSpec.describe Resources::Projects::EnvironmentVariables do
  let(:project) { create(:project) }
  let(:user) { create(:user) }
  let(:account_user) { create(:account_user, account: project.account, user: user) }

  before { account_user }

  it "returns env var names and storage types without values" do
    create(:environment_variable, project: project, name: "DATABASE_URL", value: "postgres://secret", storage_type: "secret")
    create(:environment_variable, project: project, name: "RAILS_ENV", value: "production", storage_type: "config")

    result = described_class.call(uri: "canine://projects/#{project.id}/environment_variables", user: user, account_user: account_user)
    data = JSON.parse(result.first[:text])

    expect(data.map { |e| e["name"] }).to contain_exactly("DATABASE_URL", "RAILS_ENV")
    expect(data.first).not_to include("value")
    expect(data.find { |e| e["name"] == "DATABASE_URL" }["storage_type"]).to eq("secret")
  end

  it "returns not_found for inaccessible project" do
    other_project = create(:project)
    result = described_class.call(uri: "canine://projects/#{other_project.id}/environment_variables", user: user, account_user: account_user)

    expect(result.first[:mimeType]).to eq("text/plain")
  end
end
