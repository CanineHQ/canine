# == Schema Information
#
# Table name: development_environment_configurations
#
#  id                   :bigint           not null, primary key
#  dockerfile_path      :string
#  enabled              :boolean          default(FALSE), not null
#  workspace_mount_path :string
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#  cluster_id           :bigint
#  project_id           :bigint           not null
#
# Indexes
#
#  index_development_environment_configurations_on_cluster_id  (cluster_id)
#  index_development_environment_configurations_on_project_id  (project_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (cluster_id => clusters.id)
#  fk_rails_...  (project_id => projects.id)
#
require "rails_helper"

RSpec.describe DevelopmentEnvironmentConfiguration, type: :model do
  describe "validations" do
    subject(:configuration) { build(:development_environment_configuration) }

    it { is_expected.to validate_presence_of(:project) }
    it { is_expected.to validate_uniqueness_of(:project_id) }

    it "requires cluster, dockerfile path and workspace mount path when enabled" do
      configuration.cluster = nil
      configuration.dockerfile_path = nil
      configuration.workspace_mount_path = nil

      expect(configuration).not_to be_valid
      expect(configuration.errors[:cluster]).to be_present
      expect(configuration.errors[:dockerfile_path]).to be_present
      expect(configuration.errors[:workspace_mount_path]).to be_present
    end

    it "allows blank settings when disabled" do
      configuration.enabled = false
      configuration.dockerfile_path = nil
      configuration.workspace_mount_path = nil

      expect(configuration).to be_valid
    end

    it "requires the cluster to belong to the same account as the project" do
      other_cluster = create(:cluster)
      configuration.cluster = other_cluster

      expect(configuration).not_to be_valid
      expect(configuration.errors[:cluster_id]).to include("must belong to the same account as the project")
    end
  end
end
