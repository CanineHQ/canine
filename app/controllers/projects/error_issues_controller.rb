class Projects::ErrorIssuesController < Projects::BaseController
  SORTS = {
    "last_seen" => { label: "Last seen", order: { last_seen_at: :desc, id: :desc } },
    "first_seen" => { label: "First seen", order: { first_seen_at: :desc, id: :desc } },
    "events" => { label: "Events", order: { times_seen: :desc, id: :desc } }
  }.freeze

  before_action :set_configuration
  before_action :set_error_issue, only: %i[show update destroy]

  def index
    @status = ErrorTracking::Issue.statuses.key?(params[:status]) ? params[:status] : "unresolved"
    @query = params[:q].to_s.strip
    @sort = SORTS.key?(params[:sort]) ? params[:sort] : "last_seen"
    # Carried through every link on the page so changing one control keeps the others.
    @list_params = { status: @status, sort: @sort, q: @query.presence }.compact
    issues = search_issues
    @counts = issues.group(:status).count
    @pagy, @error_issues = pagy(issues.where(status: @status).order(SORTS[@sort][:order]))
    @trends = trends(@error_issues)
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

  # Applies one action to the checked issues, or with all_matching to every issue in the current status tab and search.
  def bulk
    status = ErrorTracking::Issue.statuses.key?(params[:status]) ? params[:status] : "unresolved"
    action = params[:bulk_action]
    result = ErrorIssues::BulkUpdate.execute(
      issues: search_issues.where(status:), bulk_action: action, ids: params[:ids], all_matching: params[:all_matching] == "1"
    )
    back = project_error_issues_path(@project, status:, sort: params[:sort], q: params[:q].presence)
    return redirect_to(back, alert: result.message) if result.failure?

    message = "#{result.updated_count} #{'issue'.pluralize(result.updated_count)} #{action == 'delete' ? 'deleted' : "marked #{action}"}."
    redirect_to back, notice: message
  end

  private

  def set_configuration
    @configuration = @project.error_tracking_configuration
    return if @configuration

    redirect_to edit_project_path(@project, anchor: "error-tracking"), alert: "Error tracking is not enabled for this project."
  end

  def search_issues
    ErrorIssues::Search.execute(configuration: @configuration, query: params[:q]).issues
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

  # { issue_id => [[hour_start, count], ...] } for the last 24 hours, oldest first, for the issues on this page.
  def trends(issues)
    current = Time.current.utc.beginning_of_hour
    starts = Array.new(24) { |i| current - (23 - i).hours }
    counts = ErrorTracking::Event
      .where(issue_id: issues.map(&:id), occurred_at: starts.first..)
      .group(:issue_id, Arel.sql("date_trunc('hour', occurred_at)"))
      .count
      .each_with_object(Hash.new { |h, k| h[k] = {} }) { |((issue_id, bucket), count), h| h[issue_id][bucket.to_i] = count }

    issues.to_h { |issue| [ issue.id, starts.map { |start| [ start, counts[issue.id][start.to_i] || 0 ] } ] }
  end
end
