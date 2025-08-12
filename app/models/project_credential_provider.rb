# == Schema Information
#
# Table name: project_credential_providers
#
#  id          :bigint           not null, primary key
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  project_id  :bigint           not null
#  provider_id :bigint           not null
#
# Indexes
#
#  idx_on_project_id_provider_id_92125f73e5           (project_id,provider_id) UNIQUE
#  index_project_credential_providers_on_project_id   (project_id)
#  index_project_credential_providers_on_provider_id  (provider_id)
#
# Foreign Keys
#
#  fk_rails_...  (project_id => projects.id)
#  fk_rails_...  (provider_id => providers.id)
#
class ProjectCredentialProvider < ApplicationRecord
  belongs_to :project
  belongs_to :provider
  validates_uniqueness_of :provider_id, scope: :project_id

  delegate :used!, to: :provider
  delegate :username, to: :provider
  delegate :access_token, to: :provider
  delegate :github?, to: :provider
  delegate :container_registry?, to: :provider
  delegate :gitlab?, to: :provider
  delegate :git?, to: :provider

  def github_username
    JSON.parse(provider.auth)["info"]["nickname"]
  end

  def github_access_token
    provider&.access_token
  end
end
