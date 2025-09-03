# == Schema Information
#
# Table name: stack_managers
#
#  id                 :bigint           not null, primary key
#  provider_url       :string           not null
#  stack_manager_type :integer          default("portainer"), not null
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  account_id         :bigint           not null
#
# Indexes
#
#  index_stack_managers_on_account_id  (account_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#
FactoryBot.define do
  factory :stack_manager do
    provider_url { 'http://portainer.portainer.svc.cluster.local:9000' }
    stack_manager_type { :portainer }
    account
  end
end
