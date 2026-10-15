require "rails_helper"

RSpec.describe "Error tracking", type: :request do
  include Devise::Test::IntegrationHelpers

  let(:account) { create(:account) }
  let(:cluster) { create(:cluster, account:) }
  let(:project) { create(:project, cluster:, account:) }
  let(:configuration) { project.create_error_tracking_configuration! }
  let(:key) { configuration.public_key }
  let(:auth) { { "X-Sentry-Auth" => "Sentry sentry_version=7, sentry_key=#{key}, sentry_client=sentry.ruby/5.0" } }

  def sentry_event(value: "boom", line: 10)
    {
      event_id: SecureRandom.uuid, timestamp: Time.current.to_f, level: "error", platform: "ruby", environment: "production",
      exception: { values: [ {
        type: "RuntimeError", value:,
        stacktrace: { frames: [ { filename: "app/models/user.rb", function: "save", lineno: line, in_app: true, context_line: "raise 'boom'" } ] }
      } ] },
      tags: { "server" => "web-1" }
    }
  end

  def envelope(*events)
    ([ { sent_at: Time.current.iso8601 }.to_json ] + events.flat_map { |e| [ { type: "event" }.to_json, e.to_json ] }).join("\n")
  end

  it "ingests gzipped envelopes and store requests, grouping events into issues and reopening resolved ones" do
    post "/api/#{configuration.id}/envelope/", params: ActiveSupport::Gzip.compress(envelope(sentry_event, sentry_event(value: "boom", line: 42))),
      headers: auth.merge("Content-Encoding" => "gzip") # no Content-Type: must not be parsed as form params
    expect(response).to have_http_status(:ok)
    expect(response.headers["Access-Control-Allow-Origin"]).to eq("*")

    issue = configuration.issues.sole
    expect(issue).to have_attributes(title: "RuntimeError: boom", culprit: "app/models/user.rb in save", times_seen: 2)

    issue.resolved!
    post "/api/#{configuration.id}/store/?sentry_key=#{key}", params: sentry_event.to_json, headers: { "Content-Type" => "application/json" }
    expect(response).to have_http_status(:ok)
    expect(issue.reload).to have_attributes(times_seen: 3, status: "unresolved")
    expect(issue.events.count).to eq(3)

    other = sentry_event.deep_merge(exception: { values: [ { type: "KeyError" } ] })
    post "/api/#{configuration.id}/store/?sentry_key=#{key}", params: other.to_json, headers: { "Content-Type" => "application/json" }
    expect(configuration.issues.order(:number).map(&:short_id)).to eq([ "#{project.name.upcase}-1", "#{project.name.upcase}-2" ])

    # Two new issues in one request each take their own number (the query cache must not replay the counter update).
    new_types = %w[TypeError NameError].map { |type| sentry_event.deep_merge(exception: { values: [ { type: } ] }) }
    post "/api/#{configuration.id}/envelope/", params: envelope(*new_types), headers: auth
    expect(response).to have_http_status(:ok)
    expect(configuration.issues.order(:number).pluck(:number, :times_seen)).to eq([ [ 1, 3 ], [ 2, 1 ], [ 3, 1 ], [ 4, 1 ] ])

    post "/api/#{configuration.id}/store/?sentry_key=wrong", params: sentry_event.to_json, headers: { "Content-Type" => "application/json" }
    expect(response).to have_http_status(:unauthorized)
  end

  it "enables error tracking, then shows the DSN and the issue browser" do
    sign_in account.owner
    get project_error_issues_path(project)
    expect(response).to redirect_to(edit_project_path(project, anchor: "error-tracking"))
    get edit_project_path(project)
    expect(response.body).to include("Enable error tracking")
    expect(response.body).not_to include(project_error_issues_path(project))

    post project_error_tracking_configuration_path(project)
    configuration = project.reload.error_tracking_configuration
    post "/api/#{configuration.id}/envelope/", params: envelope(sentry_event), headers: { "X-Sentry-Auth" => "Sentry sentry_key=#{configuration.public_key}" }
    issue = configuration.issues.sole

    dsn = "http://#{configuration.public_key}@www.example.com/#{configuration.id}"
    get edit_project_path(project)
    expect(response.body).to include(dsn)

    get project_error_issues_path(project)
    expect(response.body).to include("RuntimeError: boom")
    expect(response.body).not_to include(dsn)

    get project_error_issue_path(project, issue)
    expect(response.body).to include("app/models/user.rb", "raise &#39;boom&#39;", "web-1")

    patch project_error_issue_path(project, issue, status: "ignored")
    expect(issue.reload).to be_ignored

    delete project_error_tracking_configuration_path(project)
    expect(response).to redirect_to(edit_project_path(project, anchor: "error-tracking"))
    expect(ErrorTracking::Issue.exists?(issue.id)).to be false
  end

  it "applies bulk actions to checked issues or to every issue matching the filter" do
    sign_in account.owner
    issues = 3.times.map { |i| ErrorTracking::IngestEvent.call(configuration, sentry_event(value: "boom #{i}").merge(exception: { values: [ { type: "E#{i}" } ] }).deep_stringify_keys).issue }
    ignored = ErrorTracking::IngestEvent.call(configuration, { "message" => "noise" }).issue.tap(&:ignored!)

    get project_error_issues_path(project)
    expect(response.body).to include("E0", "Mark resolved", "1 event")

    patch bulk_project_error_issues_path(project), params: { status: "unresolved", bulk_action: "resolved", ids: issues.first(2).map(&:id) }
    expect(issues.map { |i| i.reload.status }).to eq(%w[resolved resolved unresolved])

    patch bulk_project_error_issues_path(project), params: { status: "resolved", bulk_action: "delete", all_matching: "1" }
    expect(configuration.issues.pluck(:id)).to contain_exactly(issues.last.id, ignored.id)
  end

  it "accepts and renders events whose interfaces are bare lists, as the JavaScript SDKs send them" do
    sign_in account.owner
    js_event = {
      event_id: SecureRandom.hex(16), platform: "node", logentry: "not an object",
      exception: [ { type: "TypeError", value: "Cannot read properties of null", stacktrace: { frames: [ { filename: "app.js", function: "loadOrder", lineno: 3, in_app: true } ] } } ],
      breadcrumbs: [ { timestamp: Time.current.to_f, category: "http", message: "GET /orders/7" } ]
    }
    post "/api/#{configuration.id}/envelope/", params: envelope(js_event), headers: auth
    expect(response).to have_http_status(:ok)

    issue = configuration.issues.sole
    get project_error_issue_path(project, issue)
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("TypeError", "loadOrder", "GET /orders/7")
  end

  it "shows an issue's latest event with its app frames and steps between events" do
    sign_in account.owner
    events = [ "v1", "v2", "v2" ].each_with_index.map do |release, i|
      event = sentry_event.merge(release:, timestamp: (3 - i).hours.ago.to_f)
      event[:exception][:values][0][:stacktrace][:frames].unshift(filename: "gems/rack.rb", function: "call", in_app: false)
      ErrorTracking::IngestEvent.call(configuration, event.deep_stringify_keys)
    end
    issue = configuration.issues.sole
    expect(issue).to have_attributes(first_release: "v1", last_release: "v2")

    frames = ->(html) { Nokogiri::HTML(html).css("section details > summary").map { |summary| summary.text.squish } }
    get project_error_issue_path(project, issue)
    expect(response.body).to include("3 events", "in v2", "Event 1 of 3", "Show 1 library frame", "event_id=#{events[1].id}")
    expect(frames.(response.body)).to eq([ "app/models/user.rb:10 in save" ])

    get project_error_issue_path(project, issue, event_id: events[1].id, frames: "full")
    expect(response.body).to include("Event 2 of 3", "event_id=#{events[0].id}", "event_id=#{events[2].id}")
    expect(frames.(response.body)).to eq([ "app/models/user.rb:10 in save", "gems/rack.rb in call" ])
  end
end
