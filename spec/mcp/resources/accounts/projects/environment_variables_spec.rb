# frozen_string_literal: true

require "rails_helper"

RSpec.describe Resources::Accounts::Projects::EnvironmentVariables do
  let(:project) { create(:project) }
  let(:user) { create(:user) }
  let(:account_user) { create(:account_user, account: project.account, user: user) }

  before { account_user }

  it "returns environment variable names without values" do
    create(:environment_variable, project: project, name: "DATABASE_URL", value: "secret")

    uri = "canine://accounts/#{account_user.account.id}/projects/#{project.id}/environment_variables"
    result = described_class.call(uri: uri, user: user, account_users: [ account_user ])
    data = JSON.parse(result.first[:text])

    expect(data.map { |e| e["name"] }).to include("DATABASE_URL")
    expect(data.first).not_to have_key("value")
  end
end
