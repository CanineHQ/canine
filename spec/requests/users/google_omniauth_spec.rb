# frozen_string_literal: true

require 'rails_helper'

RSpec.describe "Sign in with Google", type: :request do
  include Devise::Test::IntegrationHelpers

  def mock_google(email:, verified: true)
    OmniAuth.config.mock_auth[:google_oauth2] = OmniAuth::AuthHash.new(
      provider: "google_oauth2",
      uid: "google-uid-123",
      info: { email: email, name: "Jane Doe" },
      credentials: { token: "token", expires_at: 1.hour.from_now.to_i },
      extra: { raw_info: { email_verified: verified } }
    )
  end

  around do |example|
    OmniAuth.config.test_mode = true
    example.run
  ensure
    OmniAuth.config.mock_auth[:google_oauth2] = nil
    OmniAuth.config.test_mode = false
  end

  it "creates a user with an account on first sign in, without storing a git provider" do
    mock_google(email: "Jane@Example.com")

    expect {
      post "/users/auth/google_oauth2"
      follow_redirect!
    }.to change(User, :count).by(1)

    user = User.find_by!(email: "jane@example.com")
    expect(user.owned_accounts.count).to eq(1)
    expect(user.providers).to be_empty
    expect(controller.current_user).to eq(user)

    # Signing in again reuses the same user
    sign_out user
    expect {
      post "/users/auth/google_oauth2"
      follow_redirect!
    }.not_to change(User, :count)
  end

  it "signs in an existing user by email, routing through two-factor when enabled" do
    user = create(:user, email: "jane@example.com", otp_required_for_login: true, otp_secret: User.generate_otp_secret)
    mock_google(email: "jane@example.com")

    post "/users/auth/google_oauth2"
    follow_redirect!

    expect(response).to redirect_to(new_two_factor_verification_path)
    expect(session[:otp_user_id]).to eq(user.id)
  end

  it "rejects unverified Google emails" do
    mock_google(email: "jane@example.com", verified: false)

    expect {
      post "/users/auth/google_oauth2"
      follow_redirect!
    }.not_to change(User, :count)
    expect(response).to redirect_to(new_user_session_path)
  end
end
