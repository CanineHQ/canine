# frozen_string_literal: true

require 'rails_helper'

RSpec.describe TwoFactorSetupController, type: :request do
  include Devise::Test::IntegrationHelpers

  let(:account) { create(:account) }
  let(:user) { account.owner }

  before do
    Rails.application.config.enable_2fa = true
    sign_in user
  end

  after { Rails.application.config.enable_2fa = false }

  describe 'GET #show' do
    it 'renders the disabled state when 2FA is off' do
      get two_factor_setup_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("not enabled")
    end

    it 'renders the enabled state when 2FA is on' do
      user.generate_otp_secret!
      user.update!(otp_required_for_login: true)

      get two_factor_setup_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("enabled")
    end
  end

  describe 'GET #new' do
    it 'generates a secret and shows QR code' do
      get new_two_factor_setup_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("QR code")
      expect(user.reload.otp_secret).to be_present
    end
  end

  describe 'POST #create' do
    before { user.generate_otp_secret! }

    it 'enables 2FA with valid code and shows backup codes' do
      totp = ROTP::TOTP.new(user.otp_secret)
      post two_factor_setup_path, params: { otp_code: totp.now }

      expect(user.reload.otp_required_for_login).to be true
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("backup codes")
    end

    it 'rejects invalid code' do
      post two_factor_setup_path, params: { otp_code: "000000" }
      expect(response).to have_http_status(:unprocessable_entity)
      expect(user.reload.otp_required_for_login).to be false
    end
  end

  describe 'DELETE #destroy' do
    before do
      user.generate_otp_secret!
      user.update!(otp_required_for_login: true)
    end

    it 'disables 2FA with correct password' do
      delete two_factor_setup_path, params: { password: "password" }

      expect(user.reload.two_factor_enabled?).to be false
      expect(response).to redirect_to(two_factor_setup_path)
    end

    it 'rejects incorrect password' do
      delete two_factor_setup_path, params: { password: "wrong" }

      expect(user.reload.two_factor_enabled?).to be true
      expect(response).to redirect_to(two_factor_setup_path)
    end
  end
end
