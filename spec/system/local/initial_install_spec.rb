require 'rails_helper'
require 'local_helper'

RSpec.describe "Initial Install", type: :system do
  xit "displays the initial install page" do
    visit root_path
    expect(page).to have_content("Please go to Github.com and enter your personal access token below.")
  end
end
