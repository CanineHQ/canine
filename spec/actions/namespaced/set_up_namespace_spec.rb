require 'rails_helper'

RSpec.describe Namespaced::SetUpNamespace do
  let(:subject) { described_class.execute(namespaced: project) }

  context "canine managed namespace" do
    let(:project) { build(:project, managed_namespace: true, namespace: "") }

    it "autosets the name" do
      result = subject

      expect(result.namespaced.namespace).to eq(project.name)
      expect(result.namespaced.errors).to be_empty
    end
  end

  context "self managed" do
    let(:project) { build(:project, managed_namespace: false, namespace: "") }

    it "raises error" do
      result = subject
      expect(result.namespaced.errors).to be_present
      expect(result.failure?).to be_truthy
    end
  end
end
