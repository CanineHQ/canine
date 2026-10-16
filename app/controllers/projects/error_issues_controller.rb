class Projects::ErrorIssuesController < Projects::BaseController
  TREND_PERIODS = {
    "24h" => { buckets: 24, step: 1.hour, unit: "hour" },
    "14d" => { buckets: 14, step: 1.day, unit: "day" }
  }.freeze

  before_action :set_configuration
  before_action :set_error_issue, only: %i[show update destroy]

  def index
    @status = ErrorTracking::Issue.statuses.key?(params[:status]) ? params[:status] : "unresolved"
    @period = TREND_PERIODS.key?(params[:period]) ? params[:period] : "24h"
    @counts = @configuration.issues.group(:status).count
    @pagy, @error_issues = pagy(@configuration.issues.where(status: @status).order(last_seen_at: :desc))
    @trends = trends(@error_issues, TREND_PERIODS[@period])
  end

  def show
    events = @error_issue.events
    newest_first = events.order(occurred_at: :desc, id: :desc)
    @event = params[:event_id].present? ? events.find(params[:event_id]) : newest_first.first
    @full_stack = params[:frames] == "full"
    set_event_navigation(events, newest_first) if @event
  end

  def update
    @error_issue.update!(status: params.require(:status)) if ErrorTracking::Issue.statuses.key?(params[:status])
    redirect_to project_error_issue_path(@project, @error_issue), notice: "Issue marked as #{@error_issue.status}."
  end

  def destroy
    @error_issue.destroy
    redirect_to project_error_issues_path(@project), notice: "Issue deleted."
  end

  # Applies one action to the checked issues, or with all_matching to every issue in the current status filter.
  def bulk
    status = ErrorTracking::Issue.statuses.key?(params[:status]) ? params[:status] : "unresolved"
    action = params[:bulk_action]
    result = ErrorIssues::BulkUpdate.execute(
      configuration: @configuration, status:, bulk_action: action, ids: params[:ids], all_matching: params[:all_matching] == "1"
    )
    return redirect_to(project_error_issues_path(@project, status:), alert: result.message) if result.failure?

    message = "#{result.updated_count} #{'issue'.pluralize(result.updated_count)} #{action == 'delete' ? 'deleted' : "marked #{action}"}."
    redirect_to project_error_issues_path(@project, status:, period: params[:period]), notice: message
  end

  private

  def set_configuration
    @configuration = @project.error_tracking_configuration
    return if @configuration

    redirect_to edit_project_path(@project, anchor: "error-tracking"), alert: "Error tracking is not enabled for this project."
  end

  def set_error_issue
    @error_issue = @configuration.issues.find(params[:id])
  end

  # Events are ordered by occurred_at with id as a tiebreaker, so events at the same instant are still all reachable.
  def set_event_navigation(events, newest_first)
    newer = events.where("(occurred_at, id) > (?, ?)", @event.occurred_at, @event.id)
    @newer_event = newer.order(:occurred_at, :id).first
    @older_event = events.where("(occurred_at, id) < (?, ?)", @event.occurred_at, @event.id).merge(newest_first).first
    @event_position = newer.count + 1
    @events_count = events.count
  end

  # { issue_id => [[bucket_start, count], ...] } oldest bucket first, for the issues on this page.
  def trends(issues, period)
    current = Time.current.utc.public_send(:"beginning_of_#{period[:unit]}")
    starts = Array.new(period[:buckets]) { |i| current - (period[:buckets] - 1 - i) * period[:step] }
    counts = ErrorTracking::Event
      .where(issue_id: issues.map(&:id), occurred_at: starts.first..)
      .group(:issue_id, Arel.sql("date_trunc('#{period[:unit]}', occurred_at)"))
      .count
      .each_with_object(Hash.new { |h, k| h[k] = {} }) { |((issue_id, bucket), count), h| h[issue_id][bucket.to_i] = count }

    issues.to_h { |issue| [ issue.id, starts.map { |start| [ start, counts[issue.id][start.to_i] || 0 ] } ] }
  end
end
