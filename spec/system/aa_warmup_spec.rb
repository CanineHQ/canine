require 'rails_helper'

RSpec.describe "Browser warmup", type: :system do
  it "initializes the browser" do
    visit new_user_session_path
    expect(page).to have_content("Log in")
  end
end
