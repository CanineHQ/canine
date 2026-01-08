module SystemHelpers
  include Warden::Test::Helpers

  def sign_in_user(user: nil, account: nil)
    account ||= create(:account)
    user ||= account.owner

    visit new_user_session_path
    fill_in "user_email", with: user.email
    fill_in "user_password", with: "password"
    click_button "Sign in"

    { user: user, account: account }
  end
end

RSpec.configure do |config|
  config.include SystemHelpers, type: :system

  config.before(:each, type: :system) do
    Warden.test_mode!
  end

  config.after(:each, type: :system) do
    Warden.test_reset!
  end
end
