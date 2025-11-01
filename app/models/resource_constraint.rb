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

  # Convert string input to integers (e.g., "500m" -> 500, "1Gi" -> 1073741824)
end
