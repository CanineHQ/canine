class ProjectsController < ApplicationController
  include ProjectsHelper
  before_action :set_project, only: %i[show edit update destroy restart]

  # GET /projects
  def index
    sortable_column = params[:sort] || "created_at"
    @pagy, @projects = pagy(current_account.projects.order(sortable_column => "asc"))

    # Uncomment to authorize with Pundit
    # authorize @projects
  end

  def restart
    result = Projects::Restart.execute(project: @project)
    if result.success?
      redirect_to project_url(@project), notice: "All services have been restarted"
    else
      redirect_to project_url(@project), alert: "Failed to restart all services"
    end
  end

  # GET /projects/1 or /projects/1.json
  def show
    @pagy, @events = pagy(@project.events.order(created_at: :desc))
    render "projects/deployments/index"
  end

  # GET /projects/new
  def new
    @project = Project.new

    # Uncomment to authorize with Pundit
    # authorize @project
  end

  # GET /projects/1/edit
  def edit; end

  # POST /projects or /projects.json
  def create
    result = Projects::Create.call(Project.new(project_params), params)

    @project = result.project
    respond_to do |format|
      if result.success?
        format.html { redirect_to @project, notice: "Project was successfully created." }
        format.json { render :show, status: :created, location: @project }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @project.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /projects/1 or /projects/1.json
  def update
    respond_to do |format|
      if @project.update(project_params)
        format.html { redirect_to @project, notice: "Project was successfully updated." }
        format.json { render :show, status: :ok, location: @project }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @project.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /projects/1 or /projects/1.json
  def destroy
    @project.destroy!
    respond_to do |format|
      format.html { redirect_to projects_url, status: :see_other, notice: "Project was successfully destroyed." }
      format.json { head :no_content }
    end
  end

  private

  # Use callbacks to share common setup or constraints between actions.
  def set_project
    @project = current_account.projects.find(params[:id])

    # Uncomment to authorize with Pundit
    # authorize @project
  rescue ActiveRecord::RecordNotFound
    redirect_to projects_path
  end

  # Only allow a list of trusted parameters through.
  def project_params
    params.require(:project).permit(
      :name,
      :repository_url,
      :branch,
      :cluster_id,
      :docker_build_context_directory,
      :docker_command,
      :dockerfile_path
    )
  end
end
