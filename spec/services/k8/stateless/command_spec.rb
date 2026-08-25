require 'rails_helper'

RSpec.describe K8::Stateless::Command do
  let(:project) { create(:project, name: "app-name", namespace: "app-namespace") }
  let(:command) { described_class.new(project, "predeploy", "bin/rails db:migrate") }

  it 'targets the project namespace so kubectl matches the applied job' do
    expect(command.namespace).to eq(project.namespace)
  end

  describe '#statuses' do
    it 'returns an empty list instead of false when the kubectl lookup fails' do
      failing = double("kubectl")
      allow(failing).to receive(:call).and_raise(StandardError, "boom")
      allow(command).to receive(:kubectl).and_return(failing)

      expect(command.statuses).to eq([])
    end
  end

  describe '#done?' do
    it 'reports not done rather than crashing when statuses cannot be read' do
      allow(command).to receive(:statuses).and_return([])

      expect { command.done? }.not_to raise_error
      expect(command.done?).to be(false)
    end
  end
end
