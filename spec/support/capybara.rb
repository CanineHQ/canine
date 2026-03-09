require "capybara/playwright"

Capybara.register_driver(:pw) do |app|
  Capybara::Playwright::Driver.new(app,
    browser_type: :chromium,
    headless: !ENV["HEADLESS"].in?(%w[n 0 no false])
  )
end

Capybara.default_driver = :pw
Capybara.javascript_driver = :pw
Capybara.default_max_wait_time = 15
