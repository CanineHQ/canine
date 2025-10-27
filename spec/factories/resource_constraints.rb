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
FactoryBot.define do
  factory :resource_constraint do
    association :constrainable, factory: :service
    cpu_request { 500 }        # 500m
    cpu_limit { 1000 }         # 1 CPU
    memory_request { 536870912 }  # 512Mi
    memory_limit { 1073741824 }   # 1Gi
    gpu_request { 0 }

    trait :with_project do
      association :constrainable, factory: :project
    end

    trait :with_add_on do
      association :constrainable, factory: :add_on
    end

    trait :high_resources do
      cpu_request { 2000 }      # 2 CPU
      cpu_limit { 4000 }        # 4 CPU
      memory_request { 2147483648 }  # 2Gi
      memory_limit { 4294967296 }    # 4Gi
      gpu_request { 1 }
    end

    trait :minimal do
      cpu_request { 100 }       # 100m
      cpu_limit { 250 }         # 250m
      memory_request { 134217728 }  # 128Mi
      memory_limit { 268435456 }    # 256Mi
      gpu_request { 0 }
    end
  end
end
