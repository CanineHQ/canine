FactoryBot.define do
  factory :metric do
    cluster
    metadata { {} }
    metric_type { :cpu }
    tags { [] }
  end
end
