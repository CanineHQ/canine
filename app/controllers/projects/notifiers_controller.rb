class Projects::NotifiersController < Projects::BaseController
  before_action :set_notifier, only: [ :edit, :update, :destroy ]

  def index
    render partial: "index", locals: { project: @project }
  end

  def new
    @notifier = @project.notifiers.new
  end

  def create
    @notifier = @project.notifiers.build(notifier_params)
    if @notifier.save
      render partial: "index", locals: { project: @project }
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @notifier.update(notifier_params)
      render partial: "index", locals: { project: @project }
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @notifier.destroy
    render partial: "index", locals: { project: @project }
  end

  private

  def set_notifier
    @notifier = @project.notifiers.find(params[:id])
  end

  def notifier_params
    params.require(:notifier).permit(:name, :provider_type, :webhook_url, :enabled)
  end
end
