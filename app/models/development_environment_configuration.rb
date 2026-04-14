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
class DevelopmentEnvironmentConfiguration < ApplicationRecord
  belongs_to :project

  validates :dockerfile_path, presence: true
  validates :application_path, presence: true
  validates :branch_name, presence: true
  validates :project_id, uniqueness: true

  before_validation :generate_ssh_password, on: :create

  # Get the effective API key, falling back to account level
  def effective_anthropic_api_key
    return anthropic_api_key if anthropic_api_key.present?
    return nil unless project

    # Access account through cluster to ensure proper association loading
    account = project.cluster&.account
    return nil unless account

    account.anthropic_api_key
  end

  # Check if API key is configured (either project or account level)
  def api_key_configured?
    effective_anthropic_api_key.present?
  end

  # Generate a random SSH password
  def generate_ssh_password
    self.ssh_password ||= SecureRandom.hex(16)
  end
end
