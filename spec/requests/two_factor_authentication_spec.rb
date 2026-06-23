require 'rails_helper'

RSpec.describe "Two-Factor Authentication", type: :request do
  include Devise::Test::IntegrationHelpers

  let(:account) { create(:account) }
  let(:user) { account.owner }

  def enable_2fa_for(user)
    secret = User.generate_otp_secret
    user.update!(otp_secret: secret, otp_required_for_login: true, otp_backup_codes: Array.new(12) { SecureRandom.hex(4) })
    secret
  end

  def current_otp(secret)
    ROTP::TOTP.new(secret).now
  end

  describe "setup flow" do
    before { sign_in user }

    it "generates a secret and shows QR code on create" do
      post two_factor_authentication_path
      expect(response).to have_http_status(:ok)
      expect(user.reload.otp_secret).to be_present
    end

    it "enables 2FA when a valid OTP is provided" do
      user.update!(otp_secret: User.generate_otp_secret)

      post confirm_two_factor_authentication_path, params: { otp_attempt: current_otp(user.otp_secret) }
      expect(response).to have_http_status(:ok)
      expect(user.reload.otp_required_for_login).to be true
      expect(user.otp_backup_codes).to be_present
    end

    it "rejects an invalid OTP during setup" do
      user.update!(otp_secret: User.generate_otp_secret)

      post confirm_two_factor_authentication_path, params: { otp_attempt: "000000" }
      expect(response).to have_http_status(:ok)
      expect(flash[:alert]).to include("Invalid code")
      expect(user.reload.otp_required_for_login).to be_falsey
    end

    it "disables 2FA with a valid OTP" do
      secret = enable_2fa_for(user)

      delete two_factor_authentication_path, params: { otp_attempt: current_otp(secret) }
      expect(response).to redirect_to(edit_user_registration_path)
      expect(user.reload.otp_required_for_login).to be false
      expect(user.otp_secret).to be_nil
    end

    it "rejects disabling 2FA with an invalid OTP" do
      enable_2fa_for(user)

      delete two_factor_authentication_path, params: { otp_attempt: "000000" }
      expect(response).to redirect_to(edit_user_registration_path)
      expect(flash[:alert]).to include("Invalid code")
      expect(user.reload.otp_required_for_login).to be true
    end
  end

  describe "login with 2FA" do
    it "redirects to 2FA verification after valid password" do
      secret = enable_2fa_for(user)

      post user_session_path, params: { user: { email: user.email, password: "password" } }
      expect(response).to redirect_to(new_two_factor_verification_path)
    end

    it "completes login with valid OTP" do
      secret = enable_2fa_for(user)

      post user_session_path, params: { user: { email: user.email, password: "password" } }
      follow_redirect!

      post two_factor_verification_path, params: { otp_attempt: current_otp(secret) }
      expect(response).to redirect_to(user_root_path)
    end

    it "allows login with a recovery code" do
      enable_2fa_for(user)
      recovery_code = user.otp_backup_codes.first

      post user_session_path, params: { user: { email: user.email, password: "password" } }
      follow_redirect!

      post two_factor_verification_path, params: { otp_attempt: recovery_code }
      expect(response).to redirect_to(user_root_path)
      expect(user.reload.otp_backup_codes).not_to include(recovery_code)
    end

    it "rejects an invalid OTP" do
      enable_2fa_for(user)

      post user_session_path, params: { user: { email: user.email, password: "password" } }
      follow_redirect!

      post two_factor_verification_path, params: { otp_attempt: "000000" }
      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include("Invalid code")
    end

    it "redirects to login if no OTP session exists" do
      get new_two_factor_verification_path
      expect(response).to redirect_to(new_user_session_path)
    end
  end
end
