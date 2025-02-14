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
            { name: 'NEW_VAR', value: 'new_value' }
          ]
        }
      end

      it 'creates new environment variables' do
        expect { subject }.to change { project.environment_variables.count }.by(1)
        expect(project.environment_variables.last.name).to eq('NEW_VAR')
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
