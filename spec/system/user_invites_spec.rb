require 'rails_helper'

RSpec.describe "User Invites", type: :system do
  it "allows inviting a new user who can then login and change password" do
    # User A signs in
    account = create(:account)
    user = account.owner

    visit new_user_session_path
    fill_in "user_email", with: user.email
    fill_in "user_password", with: "password"
    click_button "Sign in"
    expect(page).to have_current_path("/")

    # User A invites User B
    visit account_users_path
    click_button "Add Team Member"

    within("#team_member_modal") do
      fill_in "user_email", with: "invited@example.com"
      click_button "Invite"
    end

    # Capture the temporary password from the modal
    expect(page).to have_content("Invitation Created")
    temp_password = find("code").text

    # Close modal and logout User A
    click_button "Done"
    find('[aria-label="Avatar photo"]').click
    click_link "Logout"

    # User B logs in with temporary credentials
    visit new_user_session_path
    fill_in "user_email", with: "invited@example.com"
    fill_in "user_password", with: temp_password
    click_button "Sign in"

    # User B is redirected to change password
    expect(page).to have_content("Change Your Password")

    fill_in "user_current_password", with: temp_password
    fill_in "user_password", with: "mynewpassword123!"
    fill_in "user_password_confirmation", with: "mynewpassword123!"
    click_button "Change Password"

    expect(page).to have_content("Password changed successfully")
    expect(User.find_by(email: "invited@example.com").password_change_required).to be false
  end
end
