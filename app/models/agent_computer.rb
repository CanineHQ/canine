# == Schema Information
#
# Table name: agent_computers
#
#  id              :bigint           not null, primary key
#  browse_model    :string
#  coding_agent    :string
#  coding_model    :string
#  desktop         :string           default("selkies"), not null
#  name            :string           not null
#  namespace       :string           not null
#  password        :string
#  planning_model  :string
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
  COMPUTER_USE_PORT = 8000 # resources/agent_computer/computer_use
  SSH_PORT = 22
  CPU_CORES = 4
  # The desktop idles at ~2GiB, and an agent run (Chromium + the computer-use server + a coding agent) pushes well past
  # 4GiB, where the VM swaps hard and stalls. 8GiB keeps it out of swap. Memory, not CPU, decides how many fit on a node.
  MEMORY = "8Gi"
  DISK_SIZE = "60Gi"

  # A pickable option in the machine's model settings: id is the value stored (blank means "inherit"), name and note
  # are shown, recommended flags the ones we've seen work well. planning_model/browse_model/coding_model and
  # coding_agent are plain columns; null means inherit. The list is curated from our own benchmark runs.
  # price is OpenRouter's input / output cost per 1M tokens, shown in the picker. Update if OpenRouter's pricing moves.
  Option = Data.define(:id, :name, :note, :recommended, :icon, :price)
  MODELS = [
    Option.new("openai/gpt-5.1", "GPT-5.1", "reliable for planning & browsing", true, "logos:openai-icon", "$1.25 / $10"),
    Option.new("deepseek/deepseek-v4.1-flash", "DeepSeek V4.1 Flash", "great for coding · very cheap", true, "logos:deepseek-icon", "$0.05 / $0.60"),
    Option.new("openai/gpt-5-mini", "GPT-5 mini", "cheaper, weaker on heavy sites", false, "logos:openai-icon", "$0.25 / $2")
  ].freeze

  CODING_AGENT_OPTIONS = [
    Option.new("opencode", "opencode", nil, true, "lucide:square-terminal", nil),
    *(AgentLoop::Delegate::AGENTS.keys - [ "opencode" ]).map { |a| Option.new(a, a, nil, false, "lucide:terminal", nil) }
  ].freeze

  belongs_to :account_user
  belongs_to :cluster
  has_many :agent_tasks, dependent: :destroy
  has_many :agent_sessions, dependent: :destroy
  has_many :agent_posts, dependent: :delete_all

  has_one :user, through: :account_user
  has_one :account, through: :account_user

  # The client for the computer-use server in this computer's VM (AgentComputers::ComputerUse)
  def computer_use
    AgentComputers::ComputerUse.new(self, K8::Connection.new(cluster, user))
  end

  # The planning model a new task on this computer starts with: the machine's, or the global default.
  def default_model = planning_model.presence || AgentTask::DEFAULT_MODEL

  enum :status, { pending: 0, provisioning: 1, running: 2, stopped: 3, failed: 4, destroying: 5, starting: 6, stopping: 7 }

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
