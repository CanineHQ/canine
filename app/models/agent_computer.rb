# == Schema Information
#
# Table name: agent_computers
#
#  id              :bigint           not null, primary key
#  desktop         :string           default("selkies"), not null
#  name            :string           not null
#  namespace       :string           not null
#  password        :string
#  ssh_private_key :text
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
require "net/ssh" # adds ssh_type/to_blob to OpenSSL keys

class AgentComputer < ApplicationRecord
  include Namespaced

  NAMESPACE_PREFIX = "computer-"
  # Each agent computer is a KubeVirt VM running Omarchy (Arch Linux + Hyprland), installed unattended from the
  # Omarchy ISO and streamed to the browser by Selkies. See AgentComputer::Omarchy and ProvisionJob.
  DESKTOP_USER = "omarchy"
  DESKTOP_PORT = 8080
  SSH_PORT = 22
  CPU_CORES = 4
  # Measured: the desktop idles at ~2GiB and handled 12 heavy browser tabs with video in 4GiB (spilling ~270MiB into
  # Omarchy's compressed zram swap, no OOM kills). Memory, not CPU, decides how many computers fit on a node.
  MEMORY = "4Gi"
  DISK_SIZE = "60Gi"

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
  before_create :generate_guest_credentials

  scope :for_account, ->(account) { joins(:account_user).where(account_users: { account_id: account.id }) }

  # OpenSSH authorized_keys line for the key Canine uses to reach the guest
  def ssh_public_key
    key = OpenSSL::PKey.read(ssh_private_key)
    "#{key.ssh_type} #{[ key.to_blob ].pack("m0")} canine-#{name}"
  end

  private

  # The Omarchy installer needs a password for the desktop user; omarchy-setup.sh uses it once for sudo, then deletes
  # it (Canine is the only way in). The key is how Canine logs in to run that setup.
  def generate_guest_credentials
    self.password ||= SecureRandom.alphanumeric(16)
    self.ssh_private_key ||= OpenSSL::PKey::EC.generate("prime256v1").to_pem
  end

  def assign_namespace
    self.namespace = "#{NAMESPACE_PREFIX}#{name}" if name.present?
  end
end
