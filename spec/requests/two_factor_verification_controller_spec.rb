# frozen_string_literal: true

require 'rails_helper'

RSpec.describe TwoFactorVerificationController, type: :request do
  include Devise::Test::IntegrationHelpers

  let(:user) { create(:user) }

  before do
    Rails.application.config.enable_2fa = true
    sign_in user
  end

  after { Rails.application.config.enable_2fa = false }

  describe 'GET #show' do
    it 'redirects to root when 2FA is not enabled' do
      get two_factor_verification_path
      expect(response).to redirect_to(root_path)
    end

    it 'renders the verification form when 2FA is enabled' do
      user.generate_otp_secret!
      user.update!(otp_required_for_login: true)

      get two_factor_verification_path
      expect(response).to have_http_status(:ok)
    end
  end

  describe 'POST #create' do
    before do
      user.generate_otp_secret!
      user.update!(otp_required_for_login: true)
    end

    it 'redirects to root with valid OTP code' do
      totp = ROTP::TOTP.new(user.otp_secret)
      post two_factor_verification_path, params: { otp_code: totp.now }

      expect(response).to redirect_to(root_path)
    end

    it 'rejects invalid OTP code' do
      post two_factor_verification_path, params: { otp_code: "000000" }
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it 'accepts a valid backup code' do
      codes = user.generate_backup_codes!
      post two_factor_verification_path, params: { otp_code: codes.first }

      expect(response).to redirect_to(root_path)
    end
  end
end
