require 'rails_helper'

RSpec.describe ProjectForks::Create do
  class MockPr < Struct.new(:id, :title, :number, :branch); end

  let(:base_project) { create(:project) }
  let!(:service_1) { create(:service, project: base_project) }
  let!(:service_2) { create(:service, project: base_project) }
  let(:pull_request) { MockPr.new(id: "1", title: "Fake title", number: "7301", branch: "feature/test") }

  it 'can create a project fork from a base project' do
    result = described_class.execute(base_project:, pull_request:)
    expect(result).to be_success
    base_project.reload
    expect(base_project.forks.count).to eq(1)
  end

  it 'clones over services, project credential providers' do
    result = described_class.execute(base_project:, pull_request:)
    result.
    expect(base_project.forks.first.new_project.services.count).to eq(2)
  end
end
