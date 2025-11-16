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
class ResourceConstraint < ApplicationRecord
  include StorageHelper

  belongs_to :service

  validates :cpu_request, numericality: { only_integer: true, greater_than_or_equal_to: 0, allow_nil: true }
  validates :cpu_limit, numericality: { only_integer: true, greater_than_or_equal_to: 0, allow_nil: true }
  validates :memory_request, numericality: { only_integer: true, greater_than_or_equal_to: 0, allow_nil: true }
  validates :memory_limit, numericality: { only_integer: true, greater_than_or_equal_to: 0, allow_nil: true }
  validates :gpu_request, numericality: { only_integer: true, greater_than_or_equal_to: 0, allow_nil: true }

  # Formatted getters for Kubernetes YAML templates
  def cpu_request_formatted
    return nil if cpu_request.nil?
    integer_to_compute(cpu_request)
  end

  def cpu_limit_formatted
    return nil if cpu_limit.nil?
    integer_to_compute(cpu_limit)
  end

  def memory_request_formatted
    return nil if memory_request.nil?
    integer_to_memory(memory_request)
  end

  def memory_limit_formatted
    return nil if memory_limit.nil?
    integer_to_memory(memory_limit)
  end
end
