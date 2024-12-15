# == Schema Information
#
# Table name: clusters
#
#  id           :bigint           not null, primary key
#  cluster_type :integer          default("k8s")
#  kubeconfig   :jsonb            not null
#  name         :string           not null
#  status       :integer          default("initializing"), not null
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  account_id   :bigint           not null
#
# Indexes
#
#  index_clusters_on_account_id  (account_id)
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

  validates :name, presence: true,
                   format: { with: /\A[a-z0-9-]+\z/, message: "must be lowercase, numbers, and hyphens only" }
  enum :status, {
    initializing: 0,
    installing: 1,
    running: 2,
    failed: 3
  }
  enum :cluster_type, {
    k8s: 0,
    k3s: 1
  }
end
