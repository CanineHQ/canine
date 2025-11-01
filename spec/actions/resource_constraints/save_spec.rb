require 'rails_helper'

RSpec.describe ResourceConstraints::Save do
  let(:project) { create(:project) }
  let(:resource_constraint) { build(:resource_constraint, :with_project, constrainable: project) }

  describe '.call' do
    context 'with valid CPU core values' do
      let(:params) do
        {
          cpu_request: '0.5',
          cpu_limit: '2',
          memory_request: '512',
          memory_limit: '1024',
          gpu_request: '0'
        }
      end

      subject { described_class.execute(resource_constraint: resource_constraint, params: params) }

      it 'converts CPU cores to millicores' do
        result = subject
        expect(result).to be_success
        expect(resource_constraint.cpu_request).to eq(500)
        expect(resource_constraint.cpu_limit).to eq(2000)
      end

      it 'saves memory values as-is' do
        result = subject
        expect(result).to be_success
        expect(resource_constraint.memory_request).to eq(512)
        expect(resource_constraint.memory_limit).to eq(1024)
      end

      it 'saves the resource constraint successfully' do
        expect { subject }.to change { ResourceConstraint.count }.by(1)
      end
    end

    context 'with decimal CPU values' do
      let(:params) do
        {
          cpu_request: '1.5',
          cpu_limit: '3.25'
        }
      end

      subject { described_class.execute(resource_constraint: resource_constraint, params: params) }

      it 'converts decimal CPU cores to millicores' do
        result = subject
        expect(result).to be_success
        expect(resource_constraint.cpu_request).to eq(1500)
        expect(resource_constraint.cpu_limit).to eq(3250)
      end
    end

    context 'with integer CPU values' do
      let(:params) do
        {
          cpu_request: '2',
          cpu_limit: '4'
        }
      end

      subject { described_class.execute(resource_constraint: resource_constraint, params: params) }

      it 'converts integer CPU cores to millicores' do
        result = subject
        expect(result).to be_success
        expect(resource_constraint.cpu_request).to eq(2000)
        expect(resource_constraint.cpu_limit).to eq(4000)
      end
    end

    context 'with only cpu_request' do
      let(:params) do
        {
          cpu_request: '1'
        }
      end

      subject { described_class.execute(resource_constraint: resource_constraint, params: params) }

      it 'converts only cpu_request' do
        result = subject
        expect(result).to be_success
        expect(resource_constraint.cpu_request).to eq(1000)
      end
    end

    context 'with only cpu_limit' do
      let(:params) do
        {
          cpu_limit: '2'
        }
      end

      subject { described_class.execute(resource_constraint: resource_constraint, params: params) }

      it 'converts only cpu_limit' do
        result = subject
        expect(result).to be_success
        expect(resource_constraint.cpu_limit).to eq(2000)
      end
    end

    context 'with nil CPU values' do
      let(:resource_constraint) { ResourceConstraint.new(constrainable: project) }
      let(:params) do
        {
          memory_request: '512',
          memory_limit: '1024'
        }
      end

      subject { described_class.execute(resource_constraint: resource_constraint, params: params) }

      it 'does not set CPU values' do
        result = subject
        expect(result).to be_success
        expect(resource_constraint.cpu_request).to be_nil
        expect(resource_constraint.cpu_limit).to be_nil
      end
    end

    context 'when save fails' do
      let(:params) do
        {
          cpu_request: '0.5',
          cpu_limit: '2'
        }
      end

      subject { described_class.execute(resource_constraint: resource_constraint, params: params) }

      it 'fails with error message' do
        allow(resource_constraint).to receive(:save!).and_raise(ActiveRecord::RecordInvalid.new(resource_constraint))
        result = subject
        expect(result).to be_failure
        expect(result.message).to be_present
      end
    end

    context 'with all resource parameters' do
      let(:params) do
        {
          cpu_request: '0.5',
          cpu_limit: '2',
          memory_request: '256',
          memory_limit: '512',
          gpu_request: '1'
        }
      end

      subject { described_class.execute(resource_constraint: resource_constraint, params: params) }

      it 'saves all parameters correctly' do
        result = subject
        expect(result).to be_success
        expect(resource_constraint.cpu_request).to eq(500)
        expect(resource_constraint.cpu_limit).to eq(2000)
        expect(resource_constraint.memory_request).to eq(256)
        expect(resource_constraint.memory_limit).to eq(512)
        expect(resource_constraint.gpu_request).to eq(1)
      end
    end
  end
end
