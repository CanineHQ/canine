class Projects::ProjectForksController < Projects::BaseController
  before_action :set_project
  before_action :ensure_can_fork

  def index
    client = Git::Client.from_project(@project)
    @project_forks = @project.forks.includes(:child_project, :parent_project)
    pull_requests = client.pull_requests.select do |pr|
      @project_forks.none? { |fork| fork.external_id == pr.id.to_s }
    end

    # Merge both data sources into a unified list
    @preview_apps = []

    # Add existing project forks
    @project_forks.each do |fork|
      @preview_apps << {
        type: :project_fork,
        object: fork,
        id: fork.external_id,
        title: fork.title,
        number: fork.number,
        user: fork.user,
        url: fork.url,
        created_at: fork.created_at,
        updated_at: fork.updated_at
      }
    end

    # Add pull requests that don't have forks yet
    pull_requests.each do |pr|
      @preview_apps << {
        type: :pull_request,
        object: pr,
        id: pr.id.to_s,
        title: pr.title,
        number: pr.number,
        user: pr.user,
        url: pr.url,
        branch: pr.branch,
        created_at: pr.created_at,
        updated_at: pr.updated_at
      }
    end

    # Sort by PR number (descending)
    @preview_apps.sort! { |a, b| b[:number].to_i <=> a[:number].to_i }
  end

  def create
    client = Git::Client.from_project(@project)
    pull_request = client.pull_requests.find { |pr| pr.id.to_s == params[:pull_request_id] }
    if pull_request.nil?
      redirect_to project_project_forks_path(@project), alert: "Pull request not found"
      return
    end
    unless @project.can_fork?
      redirect_to project_project_forks_path(@project), alert: "This project cannot be forked. Only projects with a git repository can be forked."
    end

    result = ProjectForks::Create.call(
      parent_project: @project,
      pull_request:
    )
    if result.success?
      Projects::DeployLatestCommit.execute(project: result.project_fork.child_project, current_user:)
      redirect_to project_path(result.project_fork.child_project), notice: "Preview app created"
    else
      redirect_to project_project_forks_path(@project), alert: "Failed to create preview app: #{result.message}"
    end
  end

  def edit
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
