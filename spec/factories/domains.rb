# == Schema Information
#
# Table name: domains
#
#  id                  :bigint           not null, primary key
#  auto_managed        :boolean          default(FALSE)
#  domain_name         :string           not null
#  status              :integer          default("checking_dns")
#  status_reason       :string
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  ingress_endpoint_id :bigint           not null
#
# Indexes
#
#  index_domains_on_ingress_endpoint_id_and_domain_name  (ingress_endpoint_id,domain_name) UNIQUE
#
FactoryBot.define do
  factory :domain do
    service
    sequence(:domain_name) { |n| "example#{n}.com" }
    status { :checking_dns }
  end
end
