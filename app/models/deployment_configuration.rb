# == Schema Information
#
# Table name: deployment_configurations
#
#  id                :bigint           not null, primary key
#  deployment_method :integer          default("legacy"), not null
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  project_id        :bigint           not null
#
# Indexes
#
#  index_deployment_configurations_on_project_id  (project_id)
#
# Foreign Keys
#
#  fk_rails_...  (project_id => projects.id)
#
class DeploymentConfiguration < ApplicationRecord
  belongs_to :project

  validates :project, presence: true
  validates :deployment_method, presence: true

  enum :deployment_method, {
    legacy: 0,
    helm: 1
  }
end
