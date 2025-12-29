require 'rails_helper'

RSpec.describe "Registration", type: :system do
  describe "sign up" do
    it "allows a new user to sign up" do
      visit new_user_registration_path

      fill_in "Name", with: "John Doe"
      fill_in "Email", with: "john@example.com"
      fill_in "Password", with: "password123"

      click_button "Create Account"

      expect(page).to have_current_path(user_root_path)
      expect(User.find_by(email: "john@example.com")).to be_present
    end
  end

  describe "login" do
    it "allows an existing user to log in" do
      result = sign_in_user

      expect(page).to have_current_path(user_root_path)
      expect(result[:user]).to be_present
      expect(result[:account]).to be_present
    end

    it "shows an error with invalid credentials" do
      account = create(:account)

      visit new_user_session_path
      fill_in "Email", with: account.owner.email
      fill_in "Password", with: "wrongpassword"
      click_button "Sign in"

      expect(page).to have_content("Invalid Email or password")
    end
  end
end
