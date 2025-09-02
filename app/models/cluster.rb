# == Schema Information
#
# Table name: clusters
#
#  id           :bigint           not null, primary key
#  cluster_type :integer          default("k8s")
#  kubeconfig   :jsonb
#  name         :string           not null
#  status       :integer          default("initializing"), not null
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  account_id   :bigint           not null
#  external_id  :string
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
  broadcasts_refreshes
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
  enum :status, {
    initializing: 0,
    installing: 1,
    running: 2,
    failed: 3,
    destroying: 4
  }
  enum :cluster_type, {
    k8s: 0,
    k3s: 1
  }
  RESERVED_NAMESPACES = [
    "default",
    "kube-system",
    "kube-public",
    "kube-node-lease",
    "kube-flannel",
    "canine-system"
  ]

  def namespaces
    RESERVED_NAMESPACES + projects.pluck(:name) + add_ons.pluck(:name)
  end

  def create_build_cloud!(attributes = {})
    build_cloud&.destroy if build_cloud.present?
    create_build_cloud_record!(attributes)
  end

  private

  def create_build_cloud_record!(attributes)
    build_cloud = BuildCloud.new(attributes.merge(cluster: self))
    build_cloud.save!
    build_cloud
  end
end
