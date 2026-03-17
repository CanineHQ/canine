# frozen_string_literal: true

require "rails_helper"

RSpec.describe Resources::Accounts::AddOns::Show do
  let(:add_on) { create(:add_on) }
  let(:user) { create(:user) }
  let(:account_user) { create(:account_user, account: add_on.account, user: user) }

  before do
    account_user
    mock_connection = instance_double(K8::Connection)
    mock_service = instance_double(K8::Helm::Service)
    allow(K8::Connection).to receive(:new).and_return(mock_connection)
    allow(K8::Helm::Service).to receive(:create_from_add_on).with(mock_connection).and_return(mock_service)
    allow(mock_service).to receive(:get_endpoints).and_return([])
    allow(mock_service).to receive(:get_ingresses).and_return([])
    allow(mock_service).to receive(:respond_to?).with(:internal_url).and_return(false)
  end

  it "returns full add-on details" do
    uri = "canine://accounts/#{add_on.account.id}/add_ons/#{add_on.id}"
    result = described_class.call(uri: uri, user: user, account_users: [ account_user ])
    data = JSON.parse(result.first[:text])

    expect(data["id"]).to eq(add_on.id)
    expect(data["name"]).to eq(add_on.name)
    expect(data).to include("endpoints", "link_to_view_url")
  end

  it "returns not_found for inaccessible add-on" do
    other_add_on = create(:add_on)
    uri = "canine://accounts/#{add_on.account.id}/add_ons/#{other_add_on.id}"
    result = described_class.call(uri: uri, user: user, account_users: [ account_user ])

    expect(result.first[:mimeType]).to eq("text/plain")
    expect(result.first[:text]).to eq("Add-on not found")
  end
end
