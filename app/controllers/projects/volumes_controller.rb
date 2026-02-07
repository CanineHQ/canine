class Projects::VolumesController < Projects::BaseController
  def index
    render partial: "index", locals: { project: @project }
  end

  def new
    @volume = @project.volumes.new
  end

  def create
    @volume = @project.volumes.build(volume_params)
    @project.updated!
    if @volume.save
      render partial: "index", locals: { project: @project }
    else
      render :new, status: :unprocessable_entity
    end
  end

  def destroy
    @volume = @project.volumes.find(params[:id])
    @volume.destroy
    render partial: "index", locals: { project: @project }
  end

  private

  def volume_params
    params.require(:volume).permit(:name, :size, :access_mode, :mount_path)
  end
end
