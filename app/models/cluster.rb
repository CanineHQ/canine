# == Schema Information
#
# Table name: clusters
#
#  id         :bigint           not null, primary key
#  kubeconfig :jsonb            not null
#  name       :string           not null
#  status     :integer          default("initializing"), not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  user_id    :bigint           not null
#
# Indexes
#
#  index_clusters_on_user_id  (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (user_id => users.id)
#
class Cluster < ApplicationRecord
  include Loggable
  broadcasts_refreshes
  belongs_to :user
  has_many :projects, dependent: :destroy
  has_many :add_ons, dependent: :destroy
  has_many :domains, through: :projects
  has_many :metrics, dependent: :destroy
  validates_presence_of :name
  enum :status, {
    initializing: 0,
    installing: 1,
    running: 2,
    failed: 3
  }
end
