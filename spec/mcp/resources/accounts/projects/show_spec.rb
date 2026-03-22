# frozen_string_literal: true

require "rails_helper"

RSpec.describe Resources::Accounts::Projects::Show do
  let(:project) { create(:project) }
  let(:user) { create(:user) }
  let(:account_user) { create(:account_user, account: project.account, user: user) }

  before { account_user }

  it "returns full project details including services and volumes" do
    service = create(:service, project: project)
    create(:domain, service: service)

    uri = "canine://accounts/#{account_user.account.id}/projects/#{project.id}"
    result = described_class.call(uri: uri, user: user, account_users: [ account_user ])
    data = JSON.parse(result.first[:text])

    expect(data["id"]).to eq(project.id)
    expect(data).to include("services", "volumes", "builds")
    expect(data["services"].first["name"]).to eq(service.name)
    expect(data["services"].first["domains"]).to be_an(Array)
  end

  it "returns not_found for inaccessible project" do
    other_project = create(:project)
    uri = "canine://accounts/#{account_user.account.id}/projects/#{other_project.id}"
    result = described_class.call(uri: uri, user: user, account_users: [ account_user ])

    expect(result.first[:mimeType]).to eq("text/plain")
    expect(result.first[:text]).to eq("Project not found")
  end
end
