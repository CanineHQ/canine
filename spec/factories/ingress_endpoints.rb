# == Schema Information
#
# Table name: ingress_endpoints
#
#  id                :bigint           not null, primary key
#  endpoint_name     :string           not null
#  endpointable_type :string           not null
#  port              :integer          default(80), not null
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  endpointable_id   :bigint           not null
#
# Indexes
#
#  index_ingress_endpoints_uniqueness  (endpointable_type,endpointable_id,endpoint_name,port) UNIQUE
#
FactoryBot.define do
  factory :ingress_endpoint do
    association :endpointable, factory: :service
    sequence(:endpoint_name) { |n| "example-service-#{n}-service" }
    port { 80 }
  end
end
