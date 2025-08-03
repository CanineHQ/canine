# == Schema Information
#
# Table name: projects
#
#  id                             :bigint           not null, primary key
#  autodeploy                     :boolean          default(TRUE), not null
#  branch                         :string           default("main"), not null
#  canine_config                  :jsonb
#  container_registry_url         :string
#  docker_build_context_directory :string           default("."), not null
#  docker_command                 :string
#  dockerfile_path                :string           default("./Dockerfile"), not null
#  name                           :string           not null
#  postdeploy_command             :text
#  postdestroy_command            :text
#  predeploy_command              :text
#  predestroy_command             :text
#  project_fork_status            :integer          default("disabled")
#  repository_url                 :string           not null
#  status                         :integer          default("creating"), not null
#  created_at                     :datetime         not null
#  updated_at                     :datetime         not null
#  cluster_id                     :bigint           not null
#  project_fork_cluster_id        :bigint
#
# Indexes
#
#  index_projects_on_cluster_id  (cluster_id)
#
# Foreign Keys
#
#  fk_rails_...  (cluster_id => clusters.id)
#  fk_rails_...  (project_fork_cluster_id => clusters.id)
#
require 'rails_helper'

RSpec.describe Project, type: :model do
  let(:cluster) { create(:cluster) }
  let(:project) { build(:project, cluster: cluster, account: cluster.account) }

  describe 'validations' do
    context 'when name is not unique to the cluster' do
      before do
        create(:project, name: project.name, cluster: cluster)
      end

      it 'is not valid' do
        expect(project).not_to be_valid
        expect(project.errors[:name]).to include("must be unique to this cluster")
      end
    end
  end

  describe '#current_deployment' do
    it 'returns the most recent completed deployment' do
      completed_deployment = create(:deployment, project: project, status: :completed)
      create(:deployment, project: project, status: :in_progress)

      expect(project.current_deployment).to eq(completed_deployment)
    end
  end

  describe '#last_build' do
    it 'returns the most recent build' do
      create(:build, project: project)
      last_build = create(:build, project: project)

      expect(project.last_build).to eq(last_build)
    end
  end

  describe '#last_deployment' do
    it 'returns the most recent deployment' do
      create(:deployment, project: project)
      last_deployment = create(:deployment, project: project)

      expect(project.last_deployment).to eq(last_deployment)
      expect(project.last_deployment_at).to eq(last_deployment.created_at)
    end
  end

  describe '#repository_name' do
    it 'returns the name of the repository from the repository_url' do
      project.repository_url = 'owner/repository-name'
      expect(project.repository_name).to eq('repository-name')
    end
  end

  describe '#link_to_view' do
    it 'returns the full GitHub URL' do
      project.repository_url = 'owner/repository-name'
      expect(project.link_to_view).to eq('https://github.com/owner/repository-name')
    end
  end

  describe '#deployable?' do
    it 'returns true if there are services' do
      create(:service, project: project)
      expect(project.deployable?).to be true
    end

    it 'returns false if there are no services' do
      expect(project.deployable?).to be false
    end
  end

  describe '#has_updates?' do
    it 'returns true if any service is updated or pending' do
      create(:service, project: project, status: :updated)
      expect(project.has_updates?).to be true
    end

    it 'returns false if no services are updated or pending' do
      create(:service, project: project, status: :healthy)
      expect(project.has_updates?).to be false
    end
  end

  describe 'forks' do
    let(:parent_project) do
      create(
        :project,
        cluster: cluster,
        account: cluster.account,
        project_fork_cluster_id: cluster.id
      )
    end

    let!(:project_fork) do
      create(:project_fork, parent_project:, child_project: project)
    end

    it 'can determine if a project can fork' do
      expect(parent_project.can_fork?).to be_falsey
      expect(project.can_fork?).to be_falsey

      parent_project.project_fork_status = :manually_create
      parent_project.save!
      expect(parent_project.can_fork?).to be_truthy
    end

    it 'can tell if a project is a preview project' do
      expect(parent_project.forked?).to be_falsey
      expect(project.forked?).to be_truthy
    end

    it 'destroys the fork when the parent project is destroyed' do
      expect { project.destroy }.to change { ProjectFork.count }.by(-1)
    end
  end

  describe '#container_registry_url' do
    it 'uses branch name as tag for GitHub' do
      github_project = create(:project, :github, repository_url: 'owner/repo', branch: 'feature/test')
      expect(github_project.container_registry_url).to eq('ghcr.io/owner/repo:feature-test')
    end

    it 'uses latest tag for Docker Hub' do
      docker_project = create(:project, :container_registry, repository_url: 'owner/repo', branch: 'feature/test')
      expect(docker_project.container_registry_url).to eq('docker.io/owner/repo:latest')
    end
  end
end
