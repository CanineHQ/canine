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
#
# Indexes
#
#  index_build_configurations_on_build_cloud_id  (build_cloud_id)
#  index_build_configurations_on_project_id      (project_id)
#
# Foreign Keys
#
#  fk_rails_...  (build_cloud_id => build_clouds.id)
#  fk_rails_...  (project_id => projects.id)
#
require 'rails_helper'

RSpec.describe BuildConfiguration, type: :model do
  pending "add some examples to (or delete) #{__FILE__}"
end
