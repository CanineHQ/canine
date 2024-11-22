# Configure RSpec and Capybara for local system tests
RSpec.configure do |config|
  config.before(:each, type: :system, file_path: %r{spec/system/local}) do
    Capybara.app_host = 'http://localhost:3000'
    Capybara.run_server = false
    Capybara.default_host = 'localhost:3000'

    # Override default_url_options if they're set elsewhere
    Rails.application.routes.default_url_options[:host] = 'localhost:3000'
    default_url_options[:host] = 'localhost:3000'
  end
end
