# == Schema Information
#
# Table name: resource_constraints
#
#  id             :bigint           not null, primary key
#  cpu_limit      :bigint
#  cpu_request    :bigint
#  gpu_request    :integer
#  memory_limit   :bigint
#  memory_request :bigint
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  service_id     :bigint           not null
#
# Indexes
#
#  index_resource_constraints_on_service_id  (service_id)
#
require 'rails_helper'

RSpec.describe ResourceConstraint, type: :model do
  let(:resource_constraint) { build(:resource_constraint) }

  describe 'associations' do
    it { is_expected.to belong_to(:service) }
  end

  describe 'validations' do
    it 'validates numericality of resource fields' do
      resource_constraint.cpu_request = -100
      resource_constraint.memory_limit = -500
      resource_constraint.gpu_request = -1

      expect(resource_constraint).not_to be_valid
      expect(resource_constraint.errors[:cpu_request]).to be_present
      expect(resource_constraint.errors[:memory_limit]).to be_present
      expect(resource_constraint.errors[:gpu_request]).to be_present
    end
  end

  describe 'formatted methods' do
    it 'formats CPU values using millicores' do
      resource_constraint.cpu_request = 500
      resource_constraint.cpu_limit = 2000

      expect(resource_constraint.cpu_request_formatted).to eq("500m")
      expect(resource_constraint.cpu_limit_formatted).to eq("2000m")
    end

    it 'formats memory values using Kubernetes units' do
      resource_constraint.memory_request = 536870912
      resource_constraint.memory_limit = 1073741824

      expect(resource_constraint.memory_request_formatted).to eq("512Mi")
      expect(resource_constraint.memory_limit_formatted).to eq("1Gi")
    end
  end
end
