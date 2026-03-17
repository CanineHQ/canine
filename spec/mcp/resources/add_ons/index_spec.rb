# frozen_string_literal: true

require "rails_helper"

RSpec.describe Resources::AddOns::Index do
  let(:add_on) { create(:add_on) }
  let(:user) { create(:user) }
  let(:account_user) { create(:account_user, account: add_on.account, user: user) }

  before { account_user }

  it "returns all visible add-ons" do
    create(:add_on) # not visible to this user

    result = described_class.call(uri: "canine://add_ons", user: user, account_user: account_user)
    data = JSON.parse(result.first[:text])

    expect(data.map { |a| a["id"] }).to include(add_on.id)
  end

  it "returns list fields including link_to_view_url" do
    result = described_class.call(uri: "canine://add_ons", user: user, account_user: account_user)
    add_on_data = JSON.parse(result.first[:text]).first

    expect(add_on_data).to include("id", "name", "status", "link_to_view_url")
  end
end
