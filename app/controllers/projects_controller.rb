class ProjectsController < ApplicationController
  include ProjectsHelper
  before_action :set_project, only: %i[show edit update destroy restart]
  before_action :set_provider_type, only: %i[new create]

  def index
    sortable_column = params[:sort] || "created_at"
    projects = Projects::List.call(account_user: current_account_user, params: params).projects
    @pagy, @projects = pagy(projects.order(sortable_column => "asc"))

    respond_to do |format|
      format.html
      format.json { render json: @projects.map { |p| { id: p.id, name: p.name } } }
    end
  end

  def restart
    result = Projects::Restart.execute(connection: K8::Connection.new(@project, current_user))
    respond_to do |format|
      if result.success?
        format.html { redirect_to project_url(@project), notice: "All services have been restarted" }
        format.json { render json: { message: "All services have been restarted" }, status: :ok }
      else
        format.html { redirect_to project_url(@project), alert: "Failed to restart all services" }
        format.json { render json: { message: "Failed to restart all services" }, status: :unprocessable_entity }
      end
    end
  end

  def show
    @pagy, @events = pagy(@project.events.order(created_at: :desc))
    render "projects/deployments/index"
  end

  def new
    @project = Project.new
  end

  def edit
    @selectable_providers = current_account.providers.where(provider: @project.provider.provider)
  end

  def create
    result = Projects::Create.call(params, current_user)

    @project = result.project
    respond_to do |format|
      if result.success?
        format.html { redirect_to @project, notice: "Project was successfully created." }
        format.json { render :show, status: :created, location: @project }
      else
        format.html do
          @provider = @project.provider
          render :new, status: :unprocessable_entity
        end
        format.json { render json: @project.errors, status: :unprocessable_entity }
      end
    end
  end

  def update
    result = Projects::Update.call(@project, params, current_user)

    respond_to do |format|
      if result.success?
        format.html { redirect_to @project, notice: "Project is successfully updated." }
        format.json { render :show, status: :ok, location: @project }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @project.errors, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    Projects::DestroyJob.perform_later(@project, current_user)
    respond_to do |format|
      format.html { redirect_to projects_url, status: :see_other, notice: "Project is being destroyed..." }
      format.json { head :no_content }
    end
  end

  private

  def set_project
    projects = Projects::VisibleToUser.execute(account_user: current_account_user).projects
    @project = projects.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    redirect_to projects_path
  end

  def project_params
    Projects::Create.create_params(params)
  end

  def set_provider_type
    @selected_provider_type = params[:provider_type] || Provider::GIT_TYPE
    @selectable_providers = current_user.providers.where(provider: Provider::PROVIDER_TYPES[@selected_provider_type])
  end
end
