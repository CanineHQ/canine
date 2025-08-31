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
class StackManager < ApplicationRecord
  belongs_to :account

  enum :stack_manager_type, {
    portainer: 0
  }

  validates_presence_of :account, :provider_url, :stack_manager_type
  validates_uniqueness_of :account
end
