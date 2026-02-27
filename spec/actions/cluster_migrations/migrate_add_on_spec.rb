require 'rails_helper'

RSpec.describe ClusterMigrations::MigrateAddOn do
  let(:account) { create(:account) }
  let(:source_cluster) { create(:cluster, account:, status: :running) }
  let(:target_cluster) { create(:cluster, account:, status: :running) }
  let(:source_add_on) { create(:add_on, cluster: source_cluster, status: :installed, metadata: { "install_stage" => 3, "package_details" => { "name" => "redis" } }) }

  describe '#execute' do
    context 'when successful' do
      it 'creates a new add-on on the target cluster with correct attributes' do
        result = described_class.execute(source_add_on:, target_cluster:)

        expect(result).to be_success
        migrated = result.migrated_add_on
        expect(migrated.cluster_id).to eq(target_cluster.id)
        expect(migrated.name).to start_with(source_add_on.name.split("-")[0..1].join("-"))
        expect(migrated.status).to eq("installing")
        expect(migrated.metadata["install_stage"]).to eq(0)
        expect(migrated.chart_url).to eq(source_add_on.chart_url)
        expect(migrated.version).to eq(source_add_on.version)
        expect(migrated.repository_url).to eq(source_add_on.repository_url)
        expect(migrated.namespace).to eq(migrated.name)
        expect(migrated.id).not_to eq(source_add_on.id)
      end

      it 'preserves package details metadata' do
        result = described_class.execute(source_add_on:, target_cluster:)
        migrated = result.migrated_add_on

        expect(migrated.metadata["package_details"]).to eq({ "name" => "redis" })
      end
    end

    context 'when transaction fails' do
      it 'returns failure context' do
        allow(ActiveRecord::Base).to receive(:transaction).and_raise(StandardError.new("database error"))
        result = described_class.execute(source_add_on:, target_cluster:)

        expect(result).to be_failure
        expect(result.message).to include("Failed to migrate add-on")
      end
    end
  end
end
