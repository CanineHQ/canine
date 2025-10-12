require 'rails_helper'

RSpec.describe Scheduled::CheckForNewCommitsJob, type: :job do
  describe '#perform' do
    context 'when cloud mode is enabled' do
      before do
        allow(Rails.application.config).to receive(:cloud_mode).and_return(true)
      end

      it 'does not check for commits' do
        expect(Project).not_to receive(:where)
        described_class.new.perform
      end
    end

    context 'when cloud mode is disabled' do
      before do
        allow(Rails.application.config).to receive(:cloud_mode).and_return(false)
      end

      context 'with GitHub projects' do
        let!(:project) { create(:project, :github, autodeploy: true) }

        before do
          # Clear any existing autodeploy projects
          Project.where(autodeploy: true).where.not(id: project.id).destroy_all
        end

        it 'enqueues a Projects::CheckForNewCommitsJob for the project' do
          expect(Projects::CheckForNewCommitsJob).to receive(:perform_later).with(project).once
          described_class.new.perform
        end
      end

      context 'with GitLab projects' do
        let!(:project) { create(:project, :gitlab, autodeploy: true) }

        before do
          # Clear any existing autodeploy projects
          Project.where(autodeploy: true).where.not(id: project.id).destroy_all
        end

        it 'enqueues a Projects::CheckForNewCommitsJob for the project' do
          expect(Projects::CheckForNewCommitsJob).to receive(:perform_later).with(project).once
          described_class.new.perform
        end
      end

      context 'with multiple git projects' do
        let!(:github_project) { create(:project, :github, autodeploy: true) }
        let!(:gitlab_project) { create(:project, :gitlab, autodeploy: true) }

        before do
          # Clear any existing autodeploy projects
          Project.where(autodeploy: true).where.not(id: [ github_project.id, gitlab_project.id ]).destroy_all
        end

        it 'enqueues a job for each project' do
          expect(Projects::CheckForNewCommitsJob).to receive(:perform_later).with(github_project).once
          expect(Projects::CheckForNewCommitsJob).to receive(:perform_later).with(gitlab_project).once
          described_class.new.perform
        end
      end

      context 'with non-git projects' do
        let!(:non_git_project) { create(:project, :container_registry, autodeploy: true) }

        before do
          # Clear any existing autodeploy git projects
          Project.where(autodeploy: true).where.not(id: non_git_project.id).destroy_all
        end

        it 'does not enqueue jobs for non-git projects' do
          expect(Projects::CheckForNewCommitsJob).not_to receive(:perform_later)
          described_class.new.perform
        end
      end

      context 'with autodeploy disabled' do
        let!(:no_autodeploy_project) { create(:project, :github, autodeploy: false) }

        before do
          # Clear any existing autodeploy projects
          Project.where(autodeploy: true).destroy_all
        end

        it 'does not enqueue jobs for projects with autodeploy disabled' do
          expect(Projects::CheckForNewCommitsJob).not_to receive(:perform_later)
          described_class.new.perform
        end
      end
    end
  end
end
