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
require 'rails_helper'

RSpec.describe BuildConfiguration, type: :model do
  describe 'validations' do
    it { is_expected.to validate_presence_of(:project) }
    it { is_expected.to validate_presence_of(:provider) }
    it { is_expected.to validate_presence_of(:driver) }
  end

  describe 'associations' do
    it { is_expected.to belong_to(:project) }
  end

  describe 'enums' do
    it { is_expected.to define_enum_for(:driver).with_values(docker: 0, k8s: 1) }
  end
end
