class Projects::VolumesController < Projects::BaseController
  def new
    @volume = @project.volumes.new
  end

  def create
    @volume = @project.volumes.build(volume_params)
    @project.updated!
    if @volume.save
      redirect_to edit_project_path(@project), notice: "Volume saved and will be created on the next deployment"
    else
      redirect_to edit_project_path(@project), alert: "Failed to create volume"
    end
  end

  def destroy
    @volume = @project.volumes.find(params[:id])
    if @volume.destroy
      redirect_to edit_project_path(@project), notice: "Volume deleted and will be removed on the next deployment"
    else
      redirect_to edit_project_path(@project), alert: "Failed to delete volume"
    end
  end

  private

  def volume_params
    params.require(:volume).permit(:name, :size, :access_mode, :mount_path)
  end
end
