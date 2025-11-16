# spec/actions/environment_variables/bulk_update_spec.rb
require 'rails_helper'

RSpec.describe EnvironmentVariables::BulkUpdate do
  let(:project) { create(:project) }
  let(:current_user) { create(:user) }
  let(:params) { { environment_variables: [] } }

  describe '.execute' do
    subject { described_class.execute(project: project, params: params) }

    context 'when adding new environment variables' do
      let(:params) do
        {
          environment_variables: [
            { name: 'NEW_VAR', value: 'new_value', storage_type: 'config' },
            { name: 'NEW_VAR_2', value: 'new_value_2', storage_type: 'secret' }
          ]
        }
      end

      it 'creates new environment variables' do
        expect { subject }.to change { project.environment_variables.count }.by(2)
        expect(project.environment_variables.find_by(name: 'NEW_VAR').storage_type).to eq('config')
        expect(project.environment_variables.find_by(name: 'NEW_VAR_2').storage_type).to eq('secret')
      end

      it 'defaults to config storage_type when not specified' do
        subject
        expect(project.environment_variables.find_by(name: 'NEW_VAR').storage_type).to eq('config')
      end
    end

    context 'when adding new environment variables with storage_type' do
      let(:params) do
        {
          environment_variables: [
            { name: 'CONFIG_VAR', value: 'config_value', storage_type: 'config' },
            { name: 'SECRET_VAR', value: 'secret_value', storage_type: 'secret' }
          ]
        }
      end

      it 'creates environment variables with correct storage_type' do
        expect { subject }.to change { project.environment_variables.count }.by(2)
        expect(project.environment_variables.find_by(name: 'CONFIG_VAR').storage_type).to eq('config')
        expect(project.environment_variables.find_by(name: 'SECRET_VAR').storage_type).to eq('secret')
      end
    end

    context 'when updating existing environment variables' do
      before do
        project.environment_variables.create!(name: 'EXISTING_VAR', value: 'old_value')
      end

      let(:params) do
        {
          environment_variables: [
            { name: 'EXISTING_VAR', value: 'new_value' }
          ]
        }
      end

      it 'updates the existing environment variable' do
        subject
        expect(project.environment_variables.find_by(name: 'EXISTING_VAR').value).to eq('new_value')
      end
    end

    context 'when updating storage_type of existing variable' do
      before do
        project.environment_variables.create!(name: 'CONVERTABLE_VAR', value: 'some_value', storage_type: :config)
      end

      let(:params) do
        {
          environment_variables: [
            { name: 'CONVERTABLE_VAR', value: 'some_value', storage_type: 'secret' }
          ]
        }
      end

      it 'updates the storage_type' do
        subject
        expect(project.environment_variables.find_by(name: 'CONVERTABLE_VAR').storage_type).to eq('secret')
      end

      it 'creates an event for the change' do
        expect { subject }.to change {
          project.environment_variables.find_by(name: 'CONVERTABLE_VAR').events.count
        }.by(1)
      end
    end

    context 'when updating value but not storage_type' do
      before do
        project.environment_variables.create!(name: 'MIXED_VAR', value: 'old_value', storage_type: :secret)
      end

      let(:params) do
        {
          environment_variables: [
            { name: 'MIXED_VAR', value: 'new_value' }
          ]
        }
      end

      it 'updates the value but preserves storage_type' do
        subject
        var = project.environment_variables.find_by(name: 'MIXED_VAR')
        expect(var.value).to eq('new_value')
        expect(var.storage_type).to eq('secret')
      end
    end

    context 'when keep_existing_value flag is set' do
      before do
        project.environment_variables.create!(name: 'SECRET_VAR', value: 'secret_value')
        project.environment_variables.create!(name: 'PUBLIC_VAR', value: 'public_value')
      end

      let(:params) do
        {
          environment_variables: [
            { name: 'SECRET_VAR', value: '', keep_existing_value: 'true' },
            { name: 'PUBLIC_VAR', value: 'updated_value' }
          ]
        }
      end

      it 'preserves the value for variables with keep_existing_value flag' do
        subject
        expect(project.environment_variables.find_by(name: 'SECRET_VAR').value).to eq('secret_value')
        expect(project.environment_variables.find_by(name: 'PUBLIC_VAR').value).to eq('updated_value')
      end

      it 'does not create events for preserved values' do
        expect { subject }.not_to change {
          project.environment_variables.find_by(name: 'SECRET_VAR').events.count
        }
      end
    end

    context 'when removing environment variables' do
      before do
        project.environment_variables.create!(name: 'VAR_TO_REMOVE', value: 'value')
      end

      let(:params) do
        {
          environment_variables: []
        }
      end

      it 'removes the environment variable' do
        expect { subject }.to change { project.environment_variables.count }.by(-1)
      end
    end

    context 'when an error occurs' do
      let(:params) do
        {
          environment_variables: [
            { name: 'EXISTING_VAR', value: 'new_value' },
            { name: 'EXISTING_VAR', value: 'new_value_2' }
          ]
        }
      end

      it 'fails the context with an error message' do
        subject
        expect(subject).to be_failure
      end
    end
  end
end
