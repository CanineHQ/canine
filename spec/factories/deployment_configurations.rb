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
FactoryBot.define do
  factory :deployment_configuration do
    project
    deployment_method { :legacy }
  end
end
