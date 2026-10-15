require "rails_helper"

RSpec.describe ErrorTracking::IngestEvent do
  def fingerprint(value:, frames:)
    described_class.new(nil, { "exception" => { "values" => [ { "type" => "ArgumentError", "value" => value, "stacktrace" => { "frames" => frames } } ] } }).fingerprint
  end

  def frame(filename, function, lineno, in_app: true)
    { "filename" => filename, "function" => function, "lineno" => lineno, "in_app" => in_app }
  end

  it "groups the same code across line shifts, deploys, build hashes, recursion and message values, but not different code" do
    base = fingerprint(value: "user 1", frames: [
      frame("/srv/releases/20261014120000/app/models/user.rb", "save", 10),
      frame("https://cdn.example.com/assets/app-3f2a9c1d.js?v=1", "_app_views_users_show_html_erb___3241826445436936010_70128", 4)
    ])
    same = fingerprint(value: "user 2", frames: [
      frame("/srv/releases/20261015090000/app/models/user.rb", "save", 42),
      frame("/srv/releases/20261015090000/app/models/user.rb", "save", 42),
      frame("https://cdn.example.com/assets/app-77b0e4aa.js", "_app_views_users_show_html_erb___9999_1", 8)
    ])
    different = fingerprint(value: "user 1", frames: [ frame("app/models/user.rb", "destroy", 10) ])

    expect(same).to eq(base)
    expect(different).not_to eq(base)
    expect(fingerprint(value: "Order 42 failed", frames: [])).to eq(fingerprint(value: "Order 7 failed", frames: []))
    expect(fingerprint(value: "Order failed", frames: [])).not_to eq(fingerprint(value: "Payment failed", frames: []))
  end
end
