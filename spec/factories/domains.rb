# == Schema Information
#
# Table name: domains
#
#  id            :bigint           not null, primary key
#  domain_name   :string           not null
#  status        :integer          default("checking_dns")
#  status_reason :string
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  service_id    :bigint           not null
#
# Indexes
#
#  index_domains_on_service_id  (service_id)
#
FactoryBot.define do
  factory :domain do
    service
    sequence(:domain_name) { |n| "example#{n}.com" }
    status { :checking_dns }
  end
end
