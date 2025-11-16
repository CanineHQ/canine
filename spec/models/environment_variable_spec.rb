# == Schema Information
#
# Table name: environment_variables
#
#  id           :bigint           not null, primary key
#  name         :string           not null
#  storage_type :integer          default("config"), not null
#  value        :text
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  project_id   :bigint           not null
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
require 'rails_helper'

RSpec.describe EnvironmentVariable, type: :model do
  let(:project) { create(:project) }
  let(:environment_variable) { build(:environment_variable, project: project) }

  describe 'validations' do
    it 'is valid with valid attributes' do
      expect(environment_variable).to be_valid
    end

    it 'requires a name' do
      environment_variable.name = nil
      expect(environment_variable).not_to be_valid
    end

    it 'requires a value' do
      environment_variable.value = nil
      expect(environment_variable).not_to be_valid
    end

    it 'requires unique name within project scope' do
      create(:environment_variable, name: 'TEST_VAR', project: project)
      duplicate = build(:environment_variable, name: 'TEST_VAR', project: project)
      expect(duplicate).not_to be_valid
    end

    it 'allows same name across different projects' do
      other_project = create(:project)
      create(:environment_variable, name: 'TEST_VAR', project: project)
      duplicate = build(:environment_variable, name: 'TEST_VAR', project: other_project)
      expect(duplicate).to be_valid
    end

    it 'validates name format' do
      environment_variable.name = 'invalid-name'
      expect(environment_variable).not_to be_valid
      expect(environment_variable.errors[:name]).to include("can only contain uppercase letters, numbers, and underscores")
    end

    it 'validates value does not contain command injection characters' do
      [ '`', '\\', '|', '>', '<', ';' ].each do |char|
        environment_variable.value = "test#{char}value"
        expect(environment_variable).not_to be_valid
        expect(environment_variable.errors[:value]).to include("cannot contain special characters that might enable command injection")
      end
    end
  end

  describe 'storage_type enum' do
    it 'defaults to config' do
      env_var = create(:environment_variable, project: project)
      expect(env_var.storage_type).to eq('config')
      expect(env_var.config?).to be true
    end

    it 'can be set to secret' do
      env_var = create(:environment_variable, :secret, project: project)
      expect(env_var.storage_type).to eq('secret')
      expect(env_var.secret?).to be true
    end

    it 'provides scopes for filtering' do
      config_var = create(:environment_variable, storage_type: :config, project: project)
      secret_var = create(:environment_variable, :secret, project: project)

      expect(project.environment_variables.config).to include(config_var)
      expect(project.environment_variables.config).not_to include(secret_var)

      expect(project.environment_variables.secret).to include(secret_var)
      expect(project.environment_variables.secret).not_to include(config_var)
    end
  end

  describe 'before_save callbacks' do
    it 'strips whitespace from name and value' do
      env_var = create(:environment_variable, name: '  test_var  ', value: '  test value  ', project: project)
      expect(env_var.name).to eq('TEST_VAR')
      expect(env_var.value).to eq('test value')
    end

    it 'uppercases the name' do
      env_var = create(:environment_variable, name: 'test_var', project: project)
      expect(env_var.name).to eq('TEST_VAR')
    end
  end
end
