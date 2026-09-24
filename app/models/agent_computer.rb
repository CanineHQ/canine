# == Schema Information
#
# Table name: agent_computers
#
#  id              :bigint           not null, primary key
#  name            :string           not null
#  namespace       :string           not null
#  status          :integer          default("pending"), not null
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  account_user_id :bigint           not null
#  cluster_id      :bigint           not null
#
# Indexes
#
#  index_agent_computers_on_account_user_id      (account_user_id)
#  index_agent_computers_on_cluster_id_and_name  (cluster_id,name) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (account_user_id => account_users.id)
#  fk_rails_...  (cluster_id => clusters.id)
#
class AgentComputer < ApplicationRecord
  include Namespaced

  NAMESPACE_PREFIX = "computer-"
  # Each agent computer is a KubeVirt VM cloned from AgentComputer::Image: Ubuntu 24.04 with XFCE, streamed to the
  # browser by Selkies, and our computer server for agent control. See resources/agent_computer/.
  DESKTOP_USER = "computer"
  DESKTOP_PORT = 8080
  COMPUTER_SERVER_PORT = 8000
  CPU_CORES = 2
  MEMORY = "4Gi"
  DISK_SIZE = "40Gi"

  belongs_to :account_user
  belongs_to :cluster

  has_one :user, through: :account_user
  has_one :account, through: :account_user

  enum :status, { pending: 0, provisioning: 1, running: 2, stopped: 3, failed: 4, destroying: 5 }

  # Namespace names are capped at 63 characters, including the prefix
  validates :name, presence: true,
                   length: { maximum: 63 - NAMESPACE_PREFIX.length },
                   format: { with: /\A[a-z0-9-]+\z/, message: "must be lowercase, numbers, and hyphens only" }

  before_validation :assign_namespace, on: :create

  scope :for_account, ->(account) { joins(:account_user).where(account_users: { account_id: account.id }) }

  private

  def assign_namespace
    self.namespace = "#{NAMESPACE_PREFIX}#{name}" if name.present?
  end
end
