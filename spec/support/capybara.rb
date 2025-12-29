require "capybara/cuprite"

Capybara.register_driver(:cuprite) do |app|
  Capybara::Cuprite::Driver.new(
    app,
    window_size: [ 1200, 800 ],
    headless: !ENV["HEADLESS"].in?(%w[n 0 no false]),
    process_timeout: 10,
    inspector: true
  )
end

Capybara.default_driver = :cuprite
Capybara.javascript_driver = :cuprite
