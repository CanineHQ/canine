# == Schema Information
#
# Table name: resource_constraints
#
#  id                 :bigint           not null, primary key
#  constrainable_type :string           not null
#  cpu_limit          :bigint
#  cpu_request        :bigint
#  gpu_request        :integer
#  memory_limit       :bigint
#  memory_request     :bigint
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  constrainable_id   :bigint           not null
#
# Indexes
#
#  index_resource_constraints_on_constrainable  (constrainable_type,constrainable_id)
#
require 'rails_helper'

RSpec.describe ResourceConstraint, type: :model do
  let(:resource_constraint) { build(:resource_constraint) }

  describe 'associations' do
    it { is_expected.to belong_to(:constrainable) }
  end

  describe 'validations' do
    describe 'cpu_request' do
      it 'accepts valid integer values' do
        resource_constraint.cpu_request = 1000
        expect(resource_constraint).to be_valid
      end

      it 'accepts nil values' do
        resource_constraint.cpu_request = nil
        expect(resource_constraint).to be_valid
      end

      it 'rejects negative values' do
        resource_constraint.cpu_request = -100
        expect(resource_constraint).not_to be_valid
        expect(resource_constraint.errors[:cpu_request]).to be_present
      end
    end

    describe 'cpu_limit' do
      it 'accepts valid integer values' do
        resource_constraint.cpu_limit = 2000
        expect(resource_constraint).to be_valid
      end

      it 'accepts nil values' do
        resource_constraint.cpu_limit = nil
        expect(resource_constraint).to be_valid
      end

      it 'rejects negative values' do
        resource_constraint.cpu_limit = -100
        expect(resource_constraint).not_to be_valid
        expect(resource_constraint.errors[:cpu_limit]).to be_present
      end

      it 'must be greater than or equal to cpu_request' do
        resource_constraint.cpu_request = 1000
        resource_constraint.cpu_limit = 500
        expect(resource_constraint).not_to be_valid
        expect(resource_constraint.errors[:cpu_limit]).to include("must be greater than or equal to CPU request")
      end

      it 'is valid when cpu_limit equals cpu_request' do
        resource_constraint.cpu_request = 1000
        resource_constraint.cpu_limit = 1000
        expect(resource_constraint).to be_valid
      end

      it 'is valid when cpu_limit is greater than cpu_request' do
        resource_constraint.cpu_request = 500
        resource_constraint.cpu_limit = 1000
        expect(resource_constraint).to be_valid
      end

      it 'is valid when cpu_request is nil' do
        resource_constraint.cpu_request = nil
        resource_constraint.cpu_limit = 1000
        expect(resource_constraint).to be_valid
      end

      it 'is valid when cpu_limit is nil' do
        resource_constraint.cpu_request = 1000
        resource_constraint.cpu_limit = nil
        expect(resource_constraint).to be_valid
      end
    end

    describe 'memory_request' do
      it 'accepts valid integer values' do
        resource_constraint.memory_request = 1073741824
        expect(resource_constraint).to be_valid
      end

      it 'accepts nil values' do
        resource_constraint.memory_request = nil
        expect(resource_constraint).to be_valid
      end

      it 'rejects negative values' do
        resource_constraint.memory_request = -100
        expect(resource_constraint).not_to be_valid
        expect(resource_constraint.errors[:memory_request]).to be_present
      end
    end

    describe 'memory_limit' do
      it 'accepts valid integer values' do
        resource_constraint.memory_limit = 2147483648
        expect(resource_constraint).to be_valid
      end

      it 'accepts nil values' do
        resource_constraint.memory_limit = nil
        expect(resource_constraint).to be_valid
      end

      it 'rejects negative values' do
        resource_constraint.memory_limit = -100
        expect(resource_constraint).not_to be_valid
        expect(resource_constraint.errors[:memory_limit]).to be_present
      end

      it 'must be greater than or equal to memory_request' do
        resource_constraint.memory_request = 1073741824  # 1Gi
        resource_constraint.memory_limit = 536870912     # 512Mi
        expect(resource_constraint).not_to be_valid
        expect(resource_constraint.errors[:memory_limit]).to include("must be greater than or equal to memory request")
      end

      it 'is valid when memory_limit equals memory_request' do
        resource_constraint.memory_request = 1073741824
        resource_constraint.memory_limit = 1073741824
        expect(resource_constraint).to be_valid
      end

      it 'is valid when memory_limit is greater than memory_request' do
        resource_constraint.memory_request = 536870912
        resource_constraint.memory_limit = 1073741824
        expect(resource_constraint).to be_valid
      end
    end

    describe 'gpu_request' do
      it 'accepts valid integer values' do
        resource_constraint.gpu_request = 2
        expect(resource_constraint).to be_valid
      end

      it 'accepts nil values' do
        resource_constraint.gpu_request = nil
        expect(resource_constraint).to be_valid
      end

      it 'rejects negative values' do
        resource_constraint.gpu_request = -1
        expect(resource_constraint).not_to be_valid
        expect(resource_constraint.errors[:gpu_request]).to be_present
      end
    end
  end

  describe 'string setters' do
    it 'converts cpu string values to integers' do
      resource_constraint.cpu_request = "500m"
      resource_constraint.cpu_limit = "2"
      expect(resource_constraint.cpu_request).to eq(500)
      expect(resource_constraint.cpu_limit).to eq(2000)
    end

    it 'converts memory string values to integers' do
      resource_constraint.memory_request = "512Mi"
      resource_constraint.memory_limit = "1Gi"
      expect(resource_constraint.memory_request).to eq(536870912)
      expect(resource_constraint.memory_limit).to eq(1073741824)
    end

    it 'accepts integer values directly' do
      resource_constraint.cpu_request = 1000
      resource_constraint.memory_request = 1073741824
      expect(resource_constraint.cpu_request).to eq(1000)
      expect(resource_constraint.memory_request).to eq(1073741824)
    end
  end

  describe 'formatted getters' do
    it 'returns formatted cpu values' do
      resource_constraint.cpu_request = 500
      resource_constraint.cpu_limit = 2000
      expect(resource_constraint.cpu_request_formatted).to eq("500m")
      expect(resource_constraint.cpu_limit_formatted).to eq("2000m")
    end

    it 'returns formatted memory values' do
      resource_constraint.memory_request = 536870912   # 512Mi
      resource_constraint.memory_limit = 1073741824    # 1Gi
      expect(resource_constraint.memory_request_formatted).to eq("512.0Mi")
      expect(resource_constraint.memory_limit_formatted).to eq("1.0Gi")
    end

    it 'returns nil for nil values' do
      resource_constraint.cpu_request = nil
      resource_constraint.memory_limit = nil
      expect(resource_constraint.cpu_request_formatted).to be_nil
      expect(resource_constraint.memory_limit_formatted).to be_nil
    end
  end

  describe 'polymorphic associations' do
    it 'can be associated with a Service' do
      service = create(:service)
      resource_constraint = create(:resource_constraint, constrainable: service)
      expect(resource_constraint.constrainable).to eq(service)
      expect(service.resource_constraint).to eq(resource_constraint)
    end

    it 'can be associated with a Project' do
      project = create(:project)
      resource_constraint = create(:resource_constraint, constrainable: project)
      expect(resource_constraint.constrainable).to eq(project)
      expect(project.resource_constraint).to eq(resource_constraint)
    end

    it 'can be associated with an AddOn' do
      add_on = create(:add_on)
      resource_constraint = create(:resource_constraint, constrainable: add_on)
      expect(resource_constraint.constrainable).to eq(add_on)
      expect(add_on.resource_constraint).to eq(resource_constraint)
    end
  end
end
