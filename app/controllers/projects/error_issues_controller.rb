class Projects::ErrorIssuesController < Projects::BaseController
  before_action :set_configuration
  before_action :set_error_issue, only: %i[show update destroy]

  def index
    return unless @configuration

    @status = ErrorTracking::Issue.statuses.key?(params[:status]) ? params[:status] : "unresolved"
    @counts = @configuration.issues.group(:status).count
    @pagy, @error_issues = pagy(@configuration.issues.where(status: @status).order(last_seen_at: :desc))
  end

  def show
    events = @error_issue.events.order(occurred_at: :desc)
    @event = params[:event_id].present? ? events.find(params[:event_id]) : events.first
    @recent_events = events.limit(50)
  end

  def update
    @error_issue.update!(status: params.require(:status)) if ErrorTracking::Issue.statuses.key?(params[:status])
    redirect_to project_error_issue_path(@project, @error_issue), notice: "Issue marked as #{@error_issue.status}."
  end

  def destroy
    @error_issue.destroy
    redirect_to project_error_issues_path(@project), notice: "Issue deleted."
  end

  private

  def set_configuration
    @configuration = @project.error_tracking_configuration
  end

  def set_error_issue
    raise ActiveRecord::RecordNotFound unless @configuration
    @error_issue = @configuration.issues.find(params[:id])
  end
end
