# == Schema Information
#
# Table name: clusters
#
#  id              :bigint           not null, primary key
#  cluster_type    :integer          default("k8s")
#  kubeconfig      :jsonb
#  name            :string           not null
#  options         :jsonb            not null
#  skip_tls_verify :boolean          default(FALSE), not null
#  status          :integer          default("initializing"), not null
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  account_id      :bigint           not null
#  external_id     :string
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
  has_many :domains, through: :projects
  has_many :metrics, dependent: :destroy
  has_many :users, through: :account
  has_one :build_cloud, dependent: :destroy

  validates :name, presence: true,
                   format: { with: /\A[a-z0-9-]+\z/, message: "must be lowercase, numbers, and hyphens only" },
                   uniqueness: { scope: :account_id }
  validates_presence_of :kubeconfig, unless: :external?
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
    projects.pluck(:namespace) + add_ons.pluck(:namespace)
  end

  def create_build_cloud!(attributes = {})
    build_cloud&.destroy if build_cloud.present?
    create_build_cloud_record!(attributes)
  end

  def external?
    external_id.present?
  end

  private

  def create_build_cloud_record!(attributes)
    build_cloud = BuildCloud.new(attributes.merge(cluster: self))
    build_cloud.save!
    build_cloud
  end
end
