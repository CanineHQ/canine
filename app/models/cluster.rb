# == Schema Information
#
# Table name: clusters
#
#  id                         :bigint           not null, primary key
#  certificate_authority_data :text
#  cluster_type               :integer          default("k8s")
#  kubeconfig                 :jsonb
#  name                       :string           not null
#  options                    :jsonb            not null
#  server_url                 :string
#  service_account_token      :text
#  skip_tls_verify            :boolean          default(FALSE), not null
#  status                     :integer          default("initializing"), not null
#  unreachable_since          :datetime
#  created_at                 :datetime         not null
#  updated_at                 :datetime         not null
#  account_id                 :bigint           not null
#  external_id                :string
#
# Indexes
#
#  index_clusters_on_account_id_and_name  (account_id,name) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#
class Cluster < ApplicationRecord
  include Loggable
  include TeamAccessible
  include Favoriteable
  broadcasts_refreshes

  def self.ransackable_attributes(auth_object = nil)
    %w[name]
  end
  belongs_to :account

  has_many :projects, dependent: :destroy
  has_many :add_ons, dependent: :destroy
  has_many :agent_computers, dependent: :destroy
  has_many :cluster_packages, dependent: :destroy
  has_many :domains, through: :projects
  has_many :metrics, dependent: :destroy
  has_many :users, through: :account
  has_one :build_cloud, dependent: :destroy

  after_create_commit -> { account.touch }
  after_destroy_commit -> { account.touch }

  validates :name, presence: true,
                   format: { with: /\A[a-z0-9-]+\z/, message: "must be lowercase, numbers, and hyphens only" },
                   uniqueness: { scope: :account_id }
  # `kubeconfig` only ever holds a kubeconfig a user supplied: one being imported right now, or the one a cluster
  # created before service accounts was left with. Canine's own credentials live in the columns below.
  encrypts :service_account_token
  validate :credentials_present, unless: -> { external? || in_cluster? || registration_pending? }
  # Signs the registration command's URL. It stops working as soon as the cluster has registered.
  generates_token_for(:registration, expires_in: 1.day) { registration_pending? }
  enum :status, {
    initializing: 0,
    installing: 1,
    running: 2,
    failed: 3,
    destroying: 4,
    deleted: 5
  }
  enum :cluster_type, {
    k8s: 0,
    k3s: 1,
    local_k3s: 2
  }
  def namespaces
    projects.pluck(:namespace) + add_ons.pluck(:namespace) + agent_computers.pluck(:namespace)
  end

  def create_build_cloud!(attributes = {})
    build_cloud&.destroy if build_cloud.present?
    create_build_cloud_record!(attributes)
  end

  def external?
    external_id.present?
  end

  def in_cluster?
    options&.dig("in_cluster") == true
  end

  # Created without credentials, waiting for the registration command to be run against the cluster.
  def registration_pending?
    options&.dig("registration_pending") == true
  end

  # True once Canine connects as its own service account rather than with a credential the user supplied.
  def manager_service_account?
    service_account_token.present?
  end

  def service_account_name
    options&.dig("service_account_name") || K8::ManagerServiceAccount::NAME_PREFIX
  end

  # The kubeconfig Canine connects with. A user-supplied kubeconfig wins while it is present, so that an
  # import is validated against the new credentials rather than the ones it is about to replace.
  def connection_kubeconfig
    return kubeconfig if kubeconfig.present?

    service_account_kubeconfig if manager_service_account?
  end

  def service_account_kubeconfig(token: service_account_token)
    cluster_entry = { "server" => server_url }
    cluster_entry["certificate-authority-data"] = certificate_authority_data if certificate_authority_data.present?
    user = service_account_name

    {
      "apiVersion" => "v1",
      "kind" => "Config",
      "current-context" => name,
      "clusters" => [ { "name" => name, "cluster" => cluster_entry } ],
      "contexts" => [ { "name" => name, "context" => { "cluster" => name, "user" => user } } ],
      "users" => [ { "name" => user, "user" => { "token" => token } } ]
    }
  end

  scope :with_agent_computer, -> { where(id: ClusterPackage.where(name: "kubevirt", status: :installed).select(:cluster_id)) }

  private

  def credentials_present
    errors.add(:kubeconfig, :blank) if connection_kubeconfig.blank?
  end

  def create_build_cloud_record!(attributes)
    build_cloud = BuildCloud.new(attributes.merge(cluster: self))
    build_cloud.save!
    build_cloud
  end
end
