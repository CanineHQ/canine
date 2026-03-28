# frozen_string_literal: true

require "rails_helper"

RSpec.describe Resources::Accounts::Projects::Index do
  let(:project) { create(:project) }
  let(:user) { create(:user) }
  let(:account_user) { create(:account_user, account: project.account, user: user) }
  let(:uri) { "canine://accounts/#{account_user.account.id}/projects" }

  before { account_user }

  it "returns all visible projects" do
    create(:project) # not visible to this user

    result = described_class.call(uri: uri, user: user, account_users: [ account_user ])
    data = JSON.parse(result.first[:text])

    expect(data.map { |p| p["id"] }).to include(project.id)
  end

  it "returns list fields without services or builds" do
    result = described_class.call(uri: uri, user: user, account_users: [ account_user ])
    project_data = JSON.parse(result.first[:text]).first

    expect(project_data).to include("id", "name", "status", "link_to_view_url")
    expect(project_data).not_to include("services", "builds", "volumes")
  end
end
