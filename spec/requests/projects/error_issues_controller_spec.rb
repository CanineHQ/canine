require "rails_helper"

RSpec.describe Projects::ErrorIssuesController, type: :request do
  include Devise::Test::IntegrationHelpers

  let(:account) { create(:account) }
  let(:cluster) { create(:cluster, account: account) }
  let(:project) { create(:project, cluster: cluster, account: account) }
  let(:configuration) { project.create_error_tracking_configuration! }
  let!(:stripe) { ingest("Timeout talking to Stripe") }
  let!(:redis) { ingest("Redis connection refused") }

  def ingest(message)
    ErrorTracking::IngestEvent.call(configuration, { "event_id" => SecureRandom.hex(16), "message" => message }).issue
  end

  before { sign_in account.owner }

  it "sorts issues" do
    redis.update!(times_seen: 5, last_seen_at: 1.day.ago)

    get project_error_issues_path(project)
    expect(response.body.index("Timeout talking to Stripe")).to be < response.body.index("Redis connection refused")

    get project_error_issues_path(project, sort: "events")
    expect(response.body.index("Redis connection refused")).to be < response.body.index("Timeout talking to Stripe")

    get project_error_issue_path(project, stripe)
    expect(response.body).to include("1 event · #{stripe.events.first.occurred_at.utc.beginning_of_hour.strftime('%b %d %H:00')}")
  end

  it "searches issues and limits select-all bulk actions to the search" do
    get project_error_issues_path(project, q: "stripe")
    expect(response.body).to include("Timeout talking to Stripe")
    expect(response.body).not_to include("Redis connection refused")

    get project_error_issues_path(project, q: redis.short_id.downcase)
    expect(response.body).to include("Redis connection refused")
    expect(response.body).not_to include("Timeout talking to Stripe")

    patch bulk_project_error_issues_path(project), params: { status: "unresolved", q: "stripe", bulk_action: "resolved", all_matching: "1" }
    expect(response).to redirect_to(project_error_issues_path(project, status: "unresolved", q: "stripe"))
    expect(stripe.reload).to be_resolved
    expect(redis.reload).to be_unresolved
  end
end
