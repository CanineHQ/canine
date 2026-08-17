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
    if @notifier.email?
      NotifierMailer.test(current_user, @project).deliver_later
    else
      payload = test_payload(@notifier)
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

  def test_payload(notifier)
    WebhookBuilder.new
      .title(@project.name)
      .description("This is a test notification from Canine")
      .url(project_notifiers_url(@project), label: "View Notifiers")
      .status(emoji: "🔔", text: "Test", state: :success)
      .widget(label: "Notifier", value: notifier.name)
      .widget(label: "Project", value: @project.name)
      .build(notifier.provider_type)
  end
end
