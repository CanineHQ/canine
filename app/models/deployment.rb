# == Schema Information
#
# Table name: deployments
#
#  id         :bigint           not null, primary key
#  manifests  :jsonb
#  status     :integer          default("in_progress"), not null
#  version    :string
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  build_id   :bigint           not null
#
# Indexes
#
#  index_deployments_on_build_id  (build_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (build_id => builds.id)
#
class Deployment < ApplicationRecord
  include Loggable
  belongs_to :build
  has_one :project, through: :build
  enum :status, { in_progress: 0, completed: 1, failed: 2, killed: 3 }
  after_update_commit do
    self.build.broadcast_build
  end

  before_create :stamp_version

  def stamp_version
    self.version = "#{project.deployments.count + 1}.0.0"
  end

  def add_manifest(yaml)
    manifest_key = K8::Base.manifest_key(yaml)

    self.manifests ||= {}
    self.manifests[manifest_key] = yaml
    save!
  end

  def has_manifests?
    manifests.keys.any?
  end
end
