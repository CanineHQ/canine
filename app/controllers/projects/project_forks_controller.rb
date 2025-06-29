class Projects::ProjectForksController < Projects::BaseController
  before_action :set_project
  before_action :ensure_can_fork

  def index
    client = Git::Client.from_project(@project)
    @project_forks = @project.forks.includes(:child_project, :parent_project)
    @pull_requests = client.pull_requests.reject do |pr|
      @project_forks.any? { |fork| fork.external_id == pr.id }
    end
    # There can be PR's without forks, forks without an open PR, and a PR that has been forked
  end

  def create
    client = Git::Client.from_project(@project)
    pull_request = client.pull_requests.find { |pr| pr.id.to_s == params[:pull_request_id] }
    if pull_request.nil?
      redirect_to project_project_forks_path(@project), alert: "Pull request not found"
      return
    end

    result = ProjectForks::Create.execute(
      parent_project: @project,
      pull_request:
    )
    if result.success?
      child_project = result.project_fork.child_project
      redirect_to project_path(child_project), notice: "Preview app created"
    else
      redirect_to project_project_forks_path(@project), alert: "Failed to create preview app"
    end
  end

  def edit
  end

  def update
  end

  private

  def generate_title(project, external_id)
    "PR ##{external_id} - #{project.name}"
  end

  def generate_pr_url(project, external_id)
    if project.github?
      "https://github.com/#{project.repository_url}/pull/#{external_id}"
    elsif project.gitlab?
      "https://gitlab.com/#{project.repository_url}/-/merge_requests/#{external_id}"
    else
      nil
    end
  end

  def ensure_can_fork
    unless @project.can_fork?
      redirect_to project_path(@project), alert: "This project cannot be forked"
    end
  end
end
