class ResourceConstraintsController < ApplicationController
  before_action :set_constrainable
  before_action :set_resource_constraint, only: [:edit, :update, :destroy]

  def new
    @resource_constraint = @constrainable.build_resource_constraint
  end

  def create
    @resource_constraint = @constrainable.build_resource_constraint
    result = ResourceConstraints::Create.call(@resource_constraint, resource_constraint_params)

    if result.success?
      redirect_to_constrainable notice: "Resource constraints created successfully."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    result = ResourceConstraints::Update.call(@resource_constraint, resource_constraint_params)

    if result.success?
      redirect_to_constrainable notice: "Resource constraints updated successfully."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @resource_constraint.destroy
    redirect_to_constrainable notice: "Resource constraints removed."
  end

  private

  def set_constrainable
    # Determine the constrainable type and ID from params
    if params[:add_on_id]
      @constrainable = current_account.add_ons.find(params[:add_on_id])
      @constrainable_type = 'add_on'
    elsif params[:project_id]
      @constrainable = current_account.projects.find(params[:project_id])
      @constrainable_type = 'project'
    elsif params[:service_id]
      # Services are nested under projects
      project = current_account.projects.find(params[:project_id]) if params[:project_id]
      @constrainable = project.services.find(params[:service_id])
      @constrainable_type = 'service'
      @project = project
    else
      redirect_to root_path, alert: "Invalid resource"
    end
  end

  def set_resource_constraint
    @resource_constraint = @constrainable.resource_constraint
    redirect_to_constrainable(alert: "No resource constraints found.") unless @resource_constraint
  end

  def resource_constraint_params
    params.require(:resource_constraint).permit(
      :cpu_request,
      :cpu_limit,
      :memory_request,
      :memory_limit,
      :gpu_request
    )
  end

  def redirect_to_constrainable(options = {})
    case @constrainable_type
    when 'add_on'
      redirect_to edit_add_on_path(@constrainable), **options
    when 'project'
      redirect_to edit_project_path(@constrainable), **options
    when 'service'
      redirect_to project_services_path(@project), **options
    else
      redirect_to root_path, **options
    end
  end
end
