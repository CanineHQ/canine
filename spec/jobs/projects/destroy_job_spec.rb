# spec/actions/projects/create_spec.rb
require 'rails_helper'

RSpec.describe Projects::DestroyJob do
  let(:project) { create(:project) }
  let(:user) { create(:user) }
  let(:job) { described_class.new }
  let(:subject) { job.perform(project, user) }

  before do
    allow(job).to receive(:delete_namespace)
  end

  context 'with a complex project' do
    let!(:build) { create(:build, project: project) }
    let!(:deployment) { create(:deployment, build: build) }
    let!(:service) { create(:service, project: project) }
    let!(:volume) { create(:volume, project: project) }
    let!(:domain) { create(:domain, service: service) }
    let!(:environment_variable) { create(:environment_variable, project: project) }

    it 'destroys the project, builds, deployments, volumes, envvars, and services' do
      expect(job).to receive(:delete_namespace)
      expect(job).to receive(:remove_github_webhook)

      subject

      expect(project).to be_destroyed
      expect(Build.find_by_id(build.id)).to be_nil
      expect(Deployment.find_by_id(deployment.id)).to be_nil
      expect(Service.find_by_id(service.id)).to be_nil
      expect(Volume.find_by_id(volume.id)).to be_nil
      expect(Domain.find_by_id(domain.id)).to be_nil
      expect(EnvironmentVariable.find_by_id(environment_variable.id)).to be_nil
    end
  end

  context 'no shared repository urls' do
    it 'deregisters webhook' do
      expect(job).to receive(:remove_github_webhook)

      subject
    end
  end

  context 'there is another project with the same repository url' do
    let!(:project_2) { create(:project, repository_url: project.repository_url) }

    it 'does not deregister webhook' do
      expect(job).not_to receive(:remove_github_webhook)

      subject
    end
  end
end
