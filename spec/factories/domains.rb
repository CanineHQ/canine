FactoryBot.define do
  factory :domain do
    service
    sequence(:domain_name) { |n| "example#{n}.com" }
    status { :checking_dns }
  end
end
