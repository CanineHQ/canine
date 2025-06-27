require 'rails_helper'

RSpec.describe PreviewProjects::Create do
  class MockPr < Struct.new(:title, :number, :branch)
  end
  let(:base_project) { create(:project) }
  let!(:service_1) { create(:service, project: base_project) }
  let!(:service_2) { create(:service, project: base_project) }
  let(:pr) { MockPr.new("Fake title", number: "7301", branch: "feature/test") }

  it "can create a preview project from a base project" do
    result = described_class.execute(base_project:, pr:)
    expect(result).to be_success
  end
end
