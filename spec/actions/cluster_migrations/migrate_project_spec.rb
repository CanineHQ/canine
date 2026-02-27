require 'rails_helper'

RSpec.describe ClusterMigrations::MigrateProject do
  let(:account) { create(:account) }
  let(:source_cluster) { create(:cluster, account:, status: :running) }
  let(:target_cluster) { create(:cluster, account:, status: :running) }
  let(:source_project) { create(:project, account:, cluster: source_cluster, status: :deployed) }

  describe '#execute' do
    context 'when successful' do
      it 'creates a new project on the target cluster with correct attributes' do
        result = described_class.execute(source_project:, target_cluster:)

        expect(result).to be_success
        migrated = result.migrated_project
        expect(migrated.cluster_id).to eq(target_cluster.id)
        expect(migrated.name).to start_with(source_project.name)
        expect(migrated.status).to eq("creating")
        expect(migrated.current_deployment_id).to be_nil
        expect(migrated.slug).not_to eq(source_project.slug)
        expect(migrated.id).not_to eq(source_project.id)
      end

      it 'duplicates credential provider and configurations' do
        result = described_class.execute(source_project:, target_cluster:)
        migrated = result.migrated_project

        expect(migrated.project_credential_provider).to be_present
        expect(migrated.project_credential_provider.id).not_to eq(source_project.project_credential_provider.id)
        expect(migrated.build_configuration).to be_present if source_project.build_configuration.present?
        expect(migrated.deployment_configuration).to be_present
      end

      it 'duplicates services with resource constraints and domains' do
        service = create(:service, project: source_project)
        create(:resource_constraint, service:)
        create(:domain, service:)

        result = described_class.execute(source_project: source_project.reload, target_cluster:)
        migrated = result.migrated_project

        expect(migrated.services.count).to eq(1)
        new_service = migrated.services.first
        expect(new_service.name).to eq(service.name)
        expect(new_service.resource_constraint).to be_present
        expect(new_service.domains.count).to eq(1)
      end

      it 'duplicates environment variables, volumes, and notifiers' do
        create(:environment_variable, project: source_project)
        create(:volume, project: source_project, status: :deployed)
        create(:notifier, project: source_project)

        result = described_class.execute(source_project: source_project.reload, target_cluster:)
        migrated = result.migrated_project

        expect(migrated.environment_variables.count).to eq(1)
        expect(migrated.volumes.count).to eq(1)
        expect(migrated.volumes.first.status).to eq("pending")
        expect(migrated.notifiers.count).to eq(1)
      end
    end

    context 'when transaction fails' do
      it 'returns failure context' do
        allow(ActiveRecord::Base).to receive(:transaction).and_raise(StandardError.new("database error"))
        result = described_class.execute(source_project:, target_cluster:)

        expect(result).to be_failure
        expect(result.message).to include("Failed to migrate project")
      end
    end
  end
end
