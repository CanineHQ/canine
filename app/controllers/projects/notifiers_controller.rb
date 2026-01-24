class Projects::NotifiersController < Projects::BaseController
  before_action :set_notifier, only: [ :edit, :update, :destroy ]

  def new
    @notifier = @project.notifiers.new
  end

  def create
    @notifier = @project.notifiers.build(notifier_params)
    if @notifier.save
      redirect_to edit_project_path(@project), notice: "Notifier created successfully"
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @notifier.update(notifier_params)
      redirect_to edit_project_path(@project), notice: "Notifier updated successfully"
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @notifier.destroy
    redirect_to edit_project_path(@project), notice: "Notifier deleted"
  end

  private

  def set_notifier
    @notifier = @project.notifiers.find(params[:id])
  end

  def notifier_params
    params.require(:notifier).permit(:provider_type, :webhook_url, :enabled)
  end
end
