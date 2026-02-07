# == Schema Information
#
# Table name: deployments
#
#  id         :bigint           not null, primary key
#  manifests  :jsonb
#  status     :integer          default("in_progress"), not null
#  version    :string
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  build_id   :bigint           not null
#
# Indexes
#
#  index_deployments_on_build_id  (build_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (build_id => builds.id)
#
require 'rails_helper'

RSpec.describe Deployment, type: :model do
  let(:build) { create(:build) }
  let(:deployment) { create(:deployment, build: build) }

  describe 'current_deployment nullification' do
    it 'sets project current_deployment_id to null when deployment is deleted' do
      project = build.project
      project.update!(current_deployment: deployment)

      deployment.destroy!

      expect(project.reload.current_deployment_id).to be_nil
    end
  end

  describe '#stamp_version' do
    it 'sets version based on project deployment count' do
      project = build.project
      new_deployment = FactoryBot.build(:deployment, build: build)

      new_deployment.stamp_version

      expect(new_deployment.version).to eq("#{project.deployments.count + 1}.0.0")
    end
  end

  describe '#add_manifest' do
    let(:deployment_yaml) do
      <<~YAML
        apiVersion: apps/v1
        kind: Deployment
        metadata:
          name: test-app
        spec:
          replicas: 1
      YAML
    end

    let(:service_yaml) do
      <<~YAML
        apiVersion: v1
        kind: Service
        metadata:
          name: test-service
        spec:
          ports:
            - port: 80
      YAML
    end

    let(:configmap_yaml) do
      <<~YAML
        apiVersion: v1
        kind: ConfigMap
        metadata:
          name: test-config
        data:
          key: value
      YAML
    end

    it 'stores manifest with key format kind/name' do
      expect(deployment.has_manifests?).to be false

      deployment.add_manifest(deployment_yaml)

      expect(deployment.manifests['deployment/test-app']).to eq(deployment_yaml)
      expect(deployment.has_manifests?).to be true
    end

    it 'stores multiple manifests with different keys' do
      deployment.add_manifest(deployment_yaml)
      deployment.add_manifest(service_yaml)
      deployment.add_manifest(configmap_yaml)

      expect(deployment.manifests['deployment/test-app']).to eq(deployment_yaml)
      expect(deployment.manifests['service/test-service']).to eq(service_yaml)
      expect(deployment.manifests['configmap/test-config']).to eq(configmap_yaml)
    end

    it 'overwrites manifest if same kind/name is added again' do
      deployment.add_manifest(deployment_yaml)

      updated_yaml = <<~YAML
        apiVersion: apps/v1
        kind: Deployment
        metadata:
          name: test-app
        spec:
          replicas: 3
      YAML

      deployment.add_manifest(updated_yaml)

      expect(deployment.manifests['deployment/test-app']).to eq(updated_yaml)
      expect(deployment.manifests.keys.length).to eq(1)
    end

    it 'persists the changes to the database' do
      deployment.add_manifest(deployment_yaml)

      deployment.reload
      expect(deployment.manifests['deployment/test-app']).to eq(deployment_yaml)
    end
  end
end
