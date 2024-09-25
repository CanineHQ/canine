class Projects::ProjectAddOnsController < Projects::BaseController
  before_action :set_project_add_on, only: %i[show edit update destroy]

  def index
    @project_add_ons = @project.project_add_ons
  end

  def new
    @project_add_on = @project.project_add_ons.build
  end

  def create
    @project_add_on = @project.project_add_ons.build(project_add_on_params)

    if @project_add_on.save
      redirect_to project_project_add_on_path(@project, @project_add_on),
                  notice: 'Project add-on was successfully created.'
    else
      render :new
    end
  end

  def update
    if @project_add_on.update(project_add_on_params)
      redirect_to project_project_add_on_path(@project, @project_add_on),
                  notice: 'Project add-on was successfully updated.'
    else
      render :edit
    end
  end

  def destroy
    @project_add_on.destroy
    redirect_to project_project_add_ons_path(@project), notice: 'Project add-on was successfully destroyed.'
  end

  private

  def set_project_add_on
    @project_add_on = @project.project_add_ons.find(params[:id])
  end

  def project_add_on_params
    params.require(:project_add_on).permit(:project_id, :add_on_id)
  end
end
