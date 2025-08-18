# == Schema Information
#
# Table name: build_clouds
#
#  id                    :bigint           not null, primary key
#  driver_version        :string
#  error_message         :text
#  installation_metadata :jsonb
#  installed_at          :datetime
#  namespace             :string           default("canine-k8s-builder"), not null
#  status                :integer          default("pending"), not null
#  webhook_url           :string
#  created_at            :datetime         not null
#  updated_at            :datetime         not null
#  cluster_id            :bigint           not null
#
# Indexes
#
#  index_build_clouds_on_cluster_id  (cluster_id)
#
# Foreign Keys
#
#  fk_rails_...  (cluster_id => clusters.id)
#
class BuildCloud < ApplicationRecord
  include Loggable

  belongs_to :cluster

  validates :cluster_id, uniqueness: true
  validates :namespace, presence: true
  validates :status, presence: true

  enum :status, {
    pending: 0,
    installing: 1,
    active: 2,
    failed: 3,
    uninstalling: 4,
    uninstalled: 5
  }

  # Broadcast updates when the build cloud changes
  after_commit :broadcast_update

  def friendly_name
    "#{cluster.name} - #{namespace}"
  end

  def installation_details
    {
      namespace: namespace,
      driver_version: driver_version,
      webhook_url: webhook_url,
      installed_at: installed_at
    }
  end

  private

  def broadcast_update
    broadcast_replace_later_to(
      [ cluster, :build_cloud ],
      target: ActionView::RecordIdentifier.dom_id(cluster, "build_cloud"),
      partial: "clusters/build_clouds/show",
      locals: { cluster: cluster }
    )
  end
end
