# == Schema Information
#
# Table name: environment_variables
#
#  id         :bigint           not null, primary key
#  name       :string           not null
#  value      :text
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  project_id :bigint           not null
#
# Indexes
#
#  index_environment_variables_on_project_id           (project_id)
#  index_environment_variables_on_project_id_and_name  (project_id,name) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (project_id => projects.id)
#
FactoryBot.define do
  factory :environment_variable do
    project
    sequence(:name) { |n| "EXAMPLE_VAR_#{n}" }
    sequence(:value) { |n| "example_value_#{n}" }
  end
end
