require 'rails_helper'

RSpec.describe Projects::SetUpNamespace do
  let(:subject) { described_class.execute(project:) }

  context "canine managed namespace" do
    let(:project) { build(:project, managed_namespace: true, namespace: "") }

    it "autosets the name" do
      result = subject

      expect(result.project.namespace).to eq(project.name)
      expect(result.project.errors).to be_empty
    end
  end

  context "self managed" do
    let(:project) { build(:project, managed_namespace: false, namespace: "") }

    it "raises error" do
      result = subject
      expect(result.project.errors).to be_present
      expect(result.failure?).to be_truthy
    end
  end
end
