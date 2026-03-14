require "rails_helper"

RSpec.describe "Two-Factor Authentication", type: :system do
  def fill_in_otp(code)
    boxes = all("[data-otp-input-target='digit']")
    code.chars.each_with_index { |char, i| boxes[i].set(char) }
  end

  def sign_in_with_2fa(user:, account:)
    visit new_user_session_path
    fill_in "Email", with: user.email
    fill_in "Password", with: "password"
    click_button "Sign in"
    expect(page).to have_current_path(two_factor_verification_path)
    fill_in_otp(ROTP::TOTP.new(user.otp_secret).now)
    click_button "Verify"
  end

  let(:account) { create(:account) }
  let(:user) { account.owner }

  before do
    allow(Rails.application.config).to receive(:enable_2fa).and_return(true)
  end

  describe "login verification" do
    before do
      user.generate_otp_secret!
      user.update!(otp_required_for_login: true)
    end

    it "redirects to verification after login and grants access with correct code" do
      sign_in_with_2fa(user: user, account: account)
      expect(page).to have_current_path(user_root_path)
    end

    it "shows an error and stays on verification with an invalid code" do
      visit new_user_session_path
      fill_in "Email", with: user.email
      fill_in "Password", with: "password"
      click_button "Sign in"

      fill_in_otp("000000")
      click_button "Verify"

      expect(page).to have_current_path(two_factor_verification_path)
      expect(page).to have_content("Invalid verification code")
    end

    it "does not redirect to verification for users without 2FA" do
      other_user = create(:account).owner
      visit new_user_session_path
      fill_in "Email", with: other_user.email
      fill_in "Password", with: "password"
      click_button "Sign in"

      expect(page).to have_current_path(user_root_path)
    end
  end

  describe "setup" do
    it "sets up 2FA and shows backup codes" do
      sign_in_user(user: user, account: account)
      visit new_two_factor_setup_path

      expect(page).to have_content("Set Up Two-Factor Authentication")

      # Generate a valid code from the secret that was just created
      user.reload
      fill_in_otp(ROTP::TOTP.new(user.otp_secret).now)
      click_button "Verify & Enable"

      expect(page).to have_content("Two-Factor Authentication Enabled")
      expect(page).to have_content("Save these backup codes")
      expect(user.reload.two_factor_enabled?).to be true
    end

    it "shows an error with an invalid code during setup" do
      sign_in_user(user: user, account: account)
      visit new_two_factor_setup_path

      fill_in_otp("000000")
      click_button "Verify & Enable"

      expect(page).to have_content("Invalid verification code")
      expect(user.reload.two_factor_enabled?).to be false
    end
  end

  describe "disable" do
    before do
      user.generate_otp_secret!
      user.update!(otp_required_for_login: true)
    end

    it "disables 2FA with a valid authenticator code" do
      sign_in_with_2fa(user: user, account: account)
      visit two_factor_setup_path

      click_button "Disable Two-Factor Authentication"
      fill_in_otp(ROTP::TOTP.new(user.otp_secret).now)
      click_button "Disable"

      expect(page).to have_content("has been disabled")
      expect(user.reload.two_factor_enabled?).to be false
    end

    it "shows an error with an invalid code when disabling" do
      sign_in_with_2fa(user: user, account: account)
      visit two_factor_setup_path

      click_button "Disable Two-Factor Authentication"
      fill_in_otp("000000")
      click_button "Disable"

      expect(page).to have_content("Invalid authenticator code")
      expect(user.reload.two_factor_enabled?).to be true
    end
  end

  describe "require_2fa" do
    before do
      allow(Rails.application.config).to receive(:require_2fa).and_return(true)
    end

    it "redirects users without 2FA to the setup page" do
      sign_in_user(user: user, account: account)
      visit root_path

      expect(page).to have_current_path(new_two_factor_setup_path)
      expect(page).to have_content("must enable two-factor authentication")
    end
  end
end
