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
class ResourceConstraint < ApplicationRecord
  include StorageHelper

  belongs_to :constrainable, polymorphic: true

  validates :cpu_request, numericality: { only_integer: true, greater_than_or_equal_to: 0, allow_nil: true }
  validates :cpu_limit, numericality: { only_integer: true, greater_than_or_equal_to: 0, allow_nil: true }
  validates :memory_request, numericality: { only_integer: true, greater_than_or_equal_to: 0, allow_nil: true }
  validates :memory_limit, numericality: { only_integer: true, greater_than_or_equal_to: 0, allow_nil: true }
  validates :gpu_request, numericality: { only_integer: true, greater_than_or_equal_to: 0, allow_nil: true }

  validate :cpu_limit_greater_than_or_equal_to_request
  validate :memory_limit_greater_than_or_equal_to_request

  # Convert string input to integers (e.g., "500m" -> 500, "1Gi" -> 1073741824)
  def cpu_request=(value)
    return super(nil) if value.blank?
    super(value.is_a?(String) ? compute_to_integer(value) : value)
  end

  def cpu_limit=(value)
    return super(nil) if value.blank?
    super(value.is_a?(String) ? compute_to_integer(value) : value)
  end

  def memory_request=(value)
    return super(nil) if value.blank?
    super(value.is_a?(String) ? memory_to_integer(value) : value)
  end

  def memory_limit=(value)
    return super(nil) if value.blank?
    super(value.is_a?(String) ? memory_to_integer(value) : value)
  end

  # Convert integers back to human-readable strings for display
  def cpu_request_formatted
    cpu_request ? integer_to_compute(cpu_request) : nil
  end

  def cpu_limit_formatted
    cpu_limit ? integer_to_compute(cpu_limit) : nil
  end

  def memory_request_formatted
    memory_request ? integer_to_memory(memory_request) : nil
  end

  def memory_limit_formatted
    memory_limit ? integer_to_memory(memory_limit) : nil
  end

  private

  def cpu_limit_greater_than_or_equal_to_request
    return if cpu_request.blank? || cpu_limit.blank?

    if cpu_limit < cpu_request
      errors.add(:cpu_limit, "must be greater than or equal to CPU request")
    end
  end

  def memory_limit_greater_than_or_equal_to_request
    return if memory_request.blank? || memory_limit.blank?

    if memory_limit < memory_request
      errors.add(:memory_limit, "must be greater than or equal to memory request")
    end
  end
end
