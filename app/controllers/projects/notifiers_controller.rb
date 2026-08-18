class Projects::NotifiersController < Projects::BaseController
  before_action :set_notifier, only: [ :edit, :update, :destroy, :test ]

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

  def test
    result = Notifiers::SendTest.execute(notifier: @notifier, project: @project, user: current_user)
    if result.success?
      render partial: "index", locals: { project: @project, notice: "Test notification sent successfully." }
    else
      render partial: "index", locals: { project: @project, alert: "Failed to send test notification: #{result.message}" }
    end
  end

  private

  def set_notifier
    @notifier = @project.notifiers.find(params[:id])
  end

  def notifier_params
    params.require(:notifier).permit(:name, :provider_type, :webhook_url, :enabled, notification_types: [])
  end
end
