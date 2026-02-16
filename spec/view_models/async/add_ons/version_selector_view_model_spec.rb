require 'rails_helper'

RSpec.describe Async::AddOns::VersionSelectorViewModel do
  let(:account) { create(:account) }
  let(:user) { create(:user) }
  let!(:account_user) { create(:account_user, user: user, account: account) }
  let(:cluster) { create(:cluster, account: account) }
  let(:add_on) do
    create(:add_on,
      cluster: cluster,
      chart_url: "bitnami/redis",
      repository_url: "https://charts.bitnami.com/bitnami"
    )
  end

  let(:view_model) do
    described_class.new(user, add_on_id: add_on.id)
  end

  describe "#initial_render" do
    it "renders loading state" do
      expect(view_model.initial_render).to include("loading-spinner")
      expect(view_model.initial_render).to include("Fetching available versions")
    end
  end

  describe "#async_render" do
    let(:chart_versions) { [ "7.2.4", "7.2.3", "7.2.2" ] }
    let(:repository_index) { { "redis" => chart_versions } }

    context "when versions are successfully fetched" do
      before do
        allow(AddOns::FetchChartDetailsFromRepositoryUrl).to receive(:execute).and_return(
          double(success?: true, charts: repository_index)
        )
      end

      it "renders version selector with available versions" do
        result = view_model.async_render

        expect(result).to include("Version")
        expect(result).to include("7.2.4 (Latest)")
        expect(result).to include("7.2.3")
        expect(result).to include("7.2.2")
        expect(result).to include("Select a version to upgrade/downgrade to")
      end
    end

    context "when chart not found in repository" do
      before do
        allow(AddOns::FetchChartDetailsFromRepositoryUrl).to receive(:execute).and_return(
          double(success?: true, charts: {})
        )
      end

      it "renders error message" do
        result = view_model.async_render

        expect(result).to include("alert-error")
        expect(result).to include("not found in repository")
      end
    end

    context "when repository fetch fails" do
      before do
        allow(AddOns::FetchChartDetailsFromRepositoryUrl).to receive(:execute).and_return(
          double(success?: false, message: "Failed to fetch repository index")
        )
      end

      it "renders error message" do
        result = view_model.async_render

        expect(result).to include("alert-error")
        expect(result).to include("Failed to fetch repository index")
      end
    end
  end

  describe "#add_on" do
    it "returns the add_on" do
      expect(view_model.add_on).to eq(add_on)
    end
  end
end
