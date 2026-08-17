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
    test_event = TestNotifier.new(project: @project, notifier: @notifier)
    if @notifier.email?
      NotifierMailer.test_notification(current_user, test_event).deliver_now
    else
      payload = test_event.build_payload(@notifier.provider_type)
      HTTParty.post(
        @notifier.webhook_url,
        headers: { "Content-Type" => "application/json" },
        body: payload.to_json
      )
    end
  rescue StandardError => e
    Rails.logger.error "Failed to send test notification: #{e.message}"
  ensure
    render partial: "index", locals: { project: @project }
  end

  private

  def set_notifier
    @notifier = @project.notifiers.find(params[:id])
  end

  def notifier_params
    params.require(:notifier).permit(:name, :provider_type, :webhook_url, :enabled, notification_types: [])
  end

end
