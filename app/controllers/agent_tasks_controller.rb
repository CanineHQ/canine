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
    @task = @agent_computer.agent_tasks.new(model: AgentTask::DEFAULT_MODEL, spec: AgentLoop::Spec.normalize({}))
  end

  # Compile the instruction into a draft and save it, not enabled, for the person to review on its edit page. (A
  # redirect, rather than rendering the form again: Turbo ignores a form submission answered with a page.)
  def draft
    @task = @agent_computer.agent_tasks.new(task_params.except(:spec_yaml))
    key = current_account.agent_provider_keys.find_by(provider: "openrouter")
    return redirect_to(agent_provider_keys_path, alert: "Add an OpenRouter key first.") unless key

    @task.model = @task.model.presence || AgentTask::DEFAULT_MODEL
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
    session = @agent_computer.with_lock { AgentSession.start!(@task, trigger: :manual) unless @agent_computer.agent_sessions.active.exists? }
    return redirect_to(agent_computer_agent_tasks_path(@agent_computer), alert: "A session is already running on this computer.") unless session

    redirect_to agent_computer_agent_session_path(@agent_computer, session)
  end

  private

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
