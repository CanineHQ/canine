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
require 'rails_helper'

RSpec.describe ProjectCredentialProvider, type: :model do
  pending "add some examples to (or delete) #{__FILE__}"
end
