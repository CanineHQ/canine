require 'rails_helper'
require 'support/shared_contexts/with_portainer'

RSpec.describe Portainer::Authenticate do
  include_context 'with portainer'
  let(:user) { create(:user) }
  let(:stack_manager) { create(:stack_manager) }
  let(:auth_code) { 'auth_code' }

  it 'can authenticate with portainer' do
    result = described_class.execute(user:, stack_manager:, auth_code:)
    expect(result).to be_success
    expect(user.providers.first.access_token).to eql('jwt')
  end
end
