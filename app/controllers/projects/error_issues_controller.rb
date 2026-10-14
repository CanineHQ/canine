class Projects::ErrorIssuesController < Projects::BaseController
  before_action :set_error_issue, only: %i[show update destroy]

  def index
    @status = ErrorIssue.statuses.key?(params[:status]) ? params[:status] : "unresolved"
    @counts = @project.error_issues.group(:status).count
    @pagy, @error_issues = pagy(@project.error_issues.where(status: @status).order(last_seen_at: :desc))
  end

  def show
    events = @error_issue.error_events.order(occurred_at: :desc)
    @event = params[:event_id].present? ? events.find(params[:event_id]) : events.first
    @recent_events = events.limit(50)
  end

  def update
    @error_issue.update!(status: params.require(:status)) if ErrorIssue.statuses.key?(params[:status])
    redirect_to project_error_issue_path(@project, @error_issue), notice: "Issue marked as #{@error_issue.status}."
  end

  def destroy
    @error_issue.destroy
    redirect_to project_error_issues_path(@project), notice: "Issue deleted."
  end

  def regenerate_key
    @project.regenerate_error_tracking_key!
    redirect_to project_error_issues_path(@project), notice: "DSN regenerated. Update your SDK configuration with the new DSN."
  end

  private

  def set_error_issue
    @error_issue = @project.error_issues.find(params[:id])
  end
end
