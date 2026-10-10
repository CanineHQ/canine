# Tasks the agent loop runs on an agent computer on a schedule (AgentTask). A new task starts from the person's
# instruction, which `draft` compiles into a name, schedule and spec for them to review before saving.
class AgentTasksController < ApplicationController
  include AgentTasksFeature

  before_action :set_agent_computer
  before_action :set_task, only: %i[show edit update destroy run_now]

  def index
    @tasks = @agent_computer.agent_tasks.order(:name)
  end

  # A task and its runs, newest first (they update live: AgentSession broadcasts to the task's stream)
  def show
    @runs = @task.sessions.order(created_at: :desc).limit(50)
  end

  def new
    @task = @agent_computer.agent_tasks.new(model: @agent_computer.default_model, spec: AgentLoop::Spec.normalize({}),
                                            instruction: params[:instruction])
  end

  # The feed's compose box: one instruction becomes a task that either runs now (no schedule) or recurs on a preset
  # the person picked (COMPOSE_SCHEDULES, or "daily" at a time).
  def compose
    instruction = params[:instruction].to_s.strip
    return to_feed(alert: "Describe what the agent should do first.") if instruction.blank?

    schedule = compose_schedule
    return to_feed(alert: "The computer must be running to run a task now.") if schedule.blank? && !@agent_computer.running?

    @task = @agent_computer.agent_tasks.new(instruction:, name: instruction.truncate(70), model: @agent_computer.default_model,
                                            spec: AgentLoop::Spec.normalize({}), schedule:, enabled: schedule.present?)
    return to_feed(alert: @task.errors.full_messages.to_sentence) unless @task.save

    return run_now_and_redirect(@task) if schedule.blank?

    to_feed(notice: "Scheduled — first run #{helpers.time_ago_in_words(@task.next_run_at)} from now.")
  end

  # Compile the instruction into a draft and save it, not enabled, for the person to review on its edit page. (A
  # redirect, rather than rendering the form again: Turbo ignores a form submission answered with a page.)
  def draft
    @task = @agent_computer.agent_tasks.new(task_params.except(:spec_yaml))
    key = current_account.agent_provider_keys.find_by(provider: "openrouter")
    return redirect_to(agent_provider_keys_path, alert: "Add an OpenRouter key first.") unless key

    @task.model = @task.model.presence || @agent_computer.default_model
    draft = AgentLoop::Compiler.compile(@task.instruction.to_s, api_key: key.api_key, model: @task.model)
    @task.update!(name: draft.name, schedule: draft.schedule, spec: draft.spec, enabled: false)
    redirect_to edit_agent_computer_agent_task_path(@agent_computer, @task), notice: "Drafted. Review it, then enable it and save."
  rescue Llm::OpenRouter::Error => e
    flash.now[:alert] = e.message
    render :new, status: :unprocessable_entity
  end

  def create
    @task = @agent_computer.agent_tasks.new
    if assign_from_form && @task.save
      redirect_to agent_computer_agent_task_path(@agent_computer, @task), notice: "Task saved#{@task.enabled? ? ", next run #{helpers.time_ago_in_words(@task.next_run_at)} from now" : " (not enabled yet)"}."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if assign_from_form && @task.save
      redirect_to agent_computer_agent_task_path(@agent_computer, @task), notice: "Task saved."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @task.destroy!
    redirect_to agent_computer_agent_tasks_path(@agent_computer), status: :see_other, notice: "Task deleted."
  end

  def run_now
    return redirect_to(agent_computer_agent_tasks_path(@agent_computer), alert: "Computer must be running.") unless @agent_computer.running?
    session = AgentSession.start!(@task, trigger: :manual)

    redirect_to agent_computer_agent_session_path(@agent_computer, session)
  end

  # The recurring presets the compose box offers, in order, as label => cron. "now" (one-off) and "daily" (with a time)
  # are handled separately.
  COMPOSE_SCHEDULES = {
    "10m" => [ "Every 10 minutes", "*/10 * * * *" ],
    "30m" => [ "Every 30 minutes", "*/30 * * * *" ],
    "1h" => [ "Every hour", "0 * * * *" ],
    "6h" => [ "Every 6 hours", "0 */6 * * *" ]
  }.freeze

  private

  def compose_schedule
    choice = params[:every].to_s
    return nil if choice.blank? || choice == "now"
    return COMPOSE_SCHEDULES[choice].last if COMPOSE_SCHEDULES.key?(choice)
    return unless choice == "daily"

    hour, minute = params[:daily_time].to_s.split(":")
    "#{minute.to_i.clamp(0, 59)} #{hour.to_i.clamp(0, 23)} * * *"
  end

  def run_now_and_redirect(task)
    session = AgentSession.start!(task, trigger: :manual)

    # Stay on the feed — the run shows up at the top and updates live, like posting. If the computer is busy it queues
    # behind the current run and starts when that finishes.
    to_feed(notice: session.waiting_in_queue? ? "Queued — it'll run after the current session." : "On it — watch it run below.")
  end

  def to_feed(**flash)
    redirect_to agent_computer_agent_posts_path(@agent_computer), **flash
  end

  def set_agent_computer
    @agent_computer = current_account.agent_computers.find(params[:agent_computer_id])
  end

  def set_task
    @task = @agent_computer.agent_tasks.find(params[:id])
  end

  def task_params
    params.require(:agent_task).permit(:name, :instruction, :schedule, :model, :enabled, :spec_yaml)
  end

  # The spec is edited as YAML, which is easier to read and change than JSON
  def assign_from_form
    @task.assign_attributes(task_params.except(:spec_yaml))
    @task.spec = AgentLoop::Spec.normalize(YAML.safe_load(task_params[:spec_yaml].to_s) || {})
    true
  rescue Psych::Exception => e
    @task.errors.add(:spec, "isn't valid YAML: #{e.message}")
    false
  end
end
