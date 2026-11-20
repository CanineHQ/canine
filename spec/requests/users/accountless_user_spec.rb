# frozen_string_literal: true

require 'rails_helper'

RSpec.describe "User with no account and account member guards", type: :request do
  include Devise::Test::IntegrationHelpers

  it "lets a user with no account see a notice and sign out, while members can open their profile" do
    user = create(:user)
    sign_in user

    get "/"
    expect(response).to have_http_status(:forbidden)
    expect(response.body).to include("aren't a member of any account")

    delete destroy_user_session_path
    expect(response).to redirect_to(root_path)

    sign_in create(:account).owner
    get edit_user_registration_path
    expect(response).to have_http_status(:ok)
  end

  it "blocks demoting or removing the last admin or owner, and self changes" do
    account = create(:account)
    owner = account.account_users.find_by(role: :owner) || create(:account_user, account: account, role: :owner)
    admin = create(:account_user, account: account, role: :admin)
    member = create(:account_user, account: account, role: :member)

    expect(AccountUserPolicy.new(admin, admin).update?).to be false
    expect(AccountUserPolicy.new(admin, admin).destroy?).to be false
    expect(AccountUserPolicy.new(admin, member).destroy?).to be true

    expect(admin.update(role: :member)).to be true # owner still there
    admin.update!(role: :admin)
    expect(admin.destroy).to be_truthy

    expect(owner.destroy).to be false
    expect(owner.reload.update(role: :member)).to be false
  end
end
