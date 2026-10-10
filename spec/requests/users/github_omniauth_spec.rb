# frozen_string_literal: true

require 'rails_helper'

RSpec.describe "Sign in with GitHub", type: :request do
  include Devise::Test::IntegrationHelpers

  def mock_github(email:, uid: "github-uid-123", nickname: "octocat")
    OmniAuth.config.mock_auth[:github] = OmniAuth::AuthHash.new(
      provider: "github",
      uid: uid,
      info: { email: email, name: "Octo Cat", nickname: nickname },
      credentials: { token: "token", secret: nil, expires_at: 1.hour.from_now.to_i },
      extra: { raw_info: {} }
    )
  end

  # The real signed-in user, read from the Warden session rather than controller.current_user: the callback
  # reads current_user before swapping identities, which memoizes the old value for the rest of that one request.
  def session_user_id
    key = session["warden.user.user.key"]
    key && key.first.first
  end

  around do |example|
    OmniAuth.config.test_mode = true
    example.run
  ensure
    OmniAuth.config.mock_auth[:github] = nil
    OmniAuth.config.test_mode = false
  end

  it "signs in as the GitHub identity that owns the account, never a leftover session" do
    owner = create(:user, email: "owner@example.com")
    AccountUser.create!(account: Account.create!(owner: owner, name: "Owner's"), user: owner, role: :owner)
    create(:provider, :github, user: owner, uid: "github-uid-123")
    intruder = create(:user, email: "intruder@example.com")
    sign_in intruder # a stale session for a different person
    mock_github(email: "owner@example.com", uid: "github-uid-123")

    post "/users/auth/github"
    follow_redirect! # request phase -> callback (which signs in owner)

    expect(session_user_id).to eq(owner.id) # not the intruder whose session was active
  end

  it "connects a brand-new GitHub to the signed-in user without switching identity" do
    user = create(:user, email: "jane@example.com")
    sign_in user
    mock_github(email: "jane@example.com", uid: "brand-new-uid")

    expect {
      post "/users/auth/github"
      follow_redirect!
    }.to change { user.providers.where(provider: "github").count }.by(1)
    expect(session_user_id).to eq(user.id)
  end
end
