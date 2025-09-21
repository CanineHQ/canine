require 'rails_helper'

RSpec.describe Users::SessionsController, type: :controller do
  include Devise::Test::ControllerHelpers

  before do
    @request.env["devise.mapping"] = Devise.mappings[:user]
  end

  describe 'GET #account_select' do
    context 'when ACCOUNT_SIGN_IN_ONLY is true' do
      before do
        allow(Rails.application.config).to receive(:account_sign_in_only).and_return(true)
      end

      it 'allows access to the account select page' do
        get :account_select
        expect(response).to have_http_status(:success)
      end
    end

    context 'when ACCOUNT_SIGN_IN_ONLY is false' do
      before do
        allow(Rails.application.config).to receive(:account_sign_in_only).and_return(false)
      end

      it 'redirects to the standard sign in page' do
        get :account_select
        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end
end
