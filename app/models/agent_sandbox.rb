# == Schema Information
#
# Table name: agent_sandboxes
#
#  id              :bigint           not null, primary key
#  name            :string           not null
#  status          :integer          default("pending"), not null
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  account_user_id :bigint           not null
#  cluster_id      :bigint           not null
#
# Indexes
#
#  index_agent_sandboxes_on_account_user_id  (account_user_id)
#  index_agent_sandboxes_on_cluster_id       (cluster_id)
#
# Foreign Keys
#
#  fk_rails_...  (account_user_id => account_users.id)
#  fk_rails_...  (cluster_id => clusters.id)
#
class AgentSandbox < ApplicationRecord
  belongs_to :account_user
  belongs_to :cluster

  has_one :user, through: :account_user
  has_one :account, through: :account_user

  enum :status, { pending: 0, provisioning: 1, running: 2, stopped: 3, failed: 4, destroying: 5 }

  validates :name, presence: true

  scope :for_account, ->(account) { joins(:account_user).where(account_users: { account_id: account.id }) }
end
