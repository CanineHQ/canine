# == Schema Information
#
# Table name: development_environment_configurations
#
#  id                :bigint           not null, primary key
#  anthropic_api_key :string
#  application_path  :string           not null
#  branch_name       :string           not null
#  dockerfile_path   :string           not null
#  enabled           :boolean          default(TRUE)
#  ssh_password      :string
#  ssh_port          :integer          default(2222)
#  ssh_username      :string           default("developer")
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  project_id        :bigint           not null
#
# Indexes
#
#  index_development_environment_configurations_on_project_id  (project_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (project_id => projects.id)
#
FactoryBot.define do
  factory :development_environment_configuration do
    association :project
    dockerfile_path { "./Dockerfile.dev" }
    application_path { "/app" }
    anthropic_api_key { "sk-ant-test-#{SecureRandom.hex(16)}" }
    branch_name { "main" }
    ssh_username { "developer" }
    ssh_password { SecureRandom.hex(16) }
    ssh_port { 2222 }
    enabled { true }
  end
end
