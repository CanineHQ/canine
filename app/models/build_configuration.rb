# == Schema Information
#
# Table name: build_configurations
#
#  id             :bigint           not null, primary key
#  driver         :integer          not null
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  build_cloud_id :bigint
#  project_id     :bigint           not null
#  provider_id    :bigint           not null
#
# Indexes
#
#  index_build_configurations_on_build_cloud_id  (build_cloud_id)
#  index_build_configurations_on_project_id      (project_id)
#  index_build_configurations_on_provider_id     (provider_id)
#
# Foreign Keys
#
#  fk_rails_...  (build_cloud_id => build_clouds.id)
#  fk_rails_...  (project_id => projects.id)
#  fk_rails_...  (provider_id => providers.id)
#
class BuildConfiguration < ApplicationRecord
  belongs_to :project
  belongs_to :build_cloud, optional: true

  enum :driver, {
    docker: 0,
    k8s: 1
  }
  validates_presence_of :build_cloud, if: -> { driver == 'k8s' }
end
