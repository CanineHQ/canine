require "rails_helper"

RSpec.describe "Error tracking", type: :request do
  include Devise::Test::IntegrationHelpers

  let(:account) { create(:account) }
  let(:cluster) { create(:cluster, account:) }
  let(:project) { create(:project, cluster:, account:) }
  let(:key) { URI.parse(project.error_tracking_dsn("https://canine.example")).user }
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
    post "/api/#{project.id}/envelope/", params: ActiveSupport::Gzip.compress(envelope(sentry_event, sentry_event(value: "boom", line: 42))),
      headers: auth.merge("Content-Encoding" => "gzip", "Content-Type" => "application/x-sentry-envelope")
    expect(response).to have_http_status(:ok)
    expect(response.headers["Access-Control-Allow-Origin"]).to eq("*")

    issue = project.error_issues.sole
    expect(issue).to have_attributes(title: "RuntimeError: boom", culprit: "app/models/user.rb in save", times_seen: 2)

    issue.resolved!
    post "/api/#{project.id}/store/?sentry_key=#{key}", params: sentry_event.to_json, headers: { "Content-Type" => "application/json" }
    expect(response).to have_http_status(:ok)
    expect(issue.reload).to have_attributes(times_seen: 3, status: "unresolved")
    expect(issue.error_events.count).to eq(3)

    post "/api/#{project.id}/store/?sentry_key=wrong", params: sentry_event.to_json, headers: { "Content-Type" => "application/json" }
    expect(response).to have_http_status(:unauthorized)
  end

  it "shows the DSN and the issue browser" do
    sign_in account.owner
    post "/api/#{project.id}/envelope/", params: envelope(sentry_event), headers: auth
    issue = project.error_issues.sole

    get project_error_issues_path(project)
    expect(response.body).to include("http://#{key}@www.example.com/#{project.id}", "RuntimeError: boom")

    get project_error_issue_path(project, issue)
    expect(response.body).to include("app/models/user.rb", "raise &#39;boom&#39;", "web-1")

    patch project_error_issue_path(project, issue, status: "ignored")
    expect(issue.reload).to be_ignored
  end
end
