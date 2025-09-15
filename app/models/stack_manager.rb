# == Schema Information
#
# Table name: stack_managers
#
#  id                 :bigint           not null, primary key
#  access_token       :string
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
  validates_presence_of :access_token, if: :cloud?

  def cloud?
    Rails.application.config.cloud_mode
  end

  def requires_reauthentication?
    access_token.blank?
  end

  def stack
    if portainer?
      Portainer::Stack.new(self)
    end
  end
end
