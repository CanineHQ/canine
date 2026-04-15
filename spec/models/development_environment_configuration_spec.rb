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
