# frozen_string_literal: true

require "rails_helper"

RSpec.describe Resources::Schema do
  let(:user) { create(:user) }
  let(:account_user) { create(:account_user, user: user) }

  it "returns all resources and resource templates" do
    result = described_class.call(uri: "canine://schema", user: user, account_users: [ account_user ])
    data = JSON.parse(result.first[:text])

    resource_uris = data["resources"].map { |r| r["uri"] }
    template_uris = data["resource_templates"].map { |r| r["uri_template"] }

    expect(resource_uris).to include("canine://accounts", "canine://providers")
    expect(template_uris).to include(
      "canine://accounts/{account_id}/clusters",
      "canine://accounts/{account_id}/projects",
      "canine://accounts/{account_id}/projects/{project_id}",
      "canine://accounts/{account_id}/projects/{project_id}/builds",
      "canine://accounts/{account_id}/projects/{project_id}/environment_variables",
      "canine://accounts/{account_id}/add_ons",
      "canine://accounts/{account_id}/add_ons/{add_on_id}"
    )
  end
end
