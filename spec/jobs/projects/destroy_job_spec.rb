# spec/actions/projects/create_spec.rb
require 'rails_helper'

RSpec.describe Projects::DestroyJob do
  let(:project) { create(:project) }
  let(:job) { described_class.new }
  let(:subject) { job.perform(project) }

  before do
    allow(job).to receive(:delete_namespace)
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
