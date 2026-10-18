class AgentComputersController < ApplicationController
  include AgentComputers::FeatureGate
  before_action :set_agent_computer, only: %i[show edit update destroy connect stats stop start]
  before_action :require_running, only: %i[connect]

  def index
    @agent_computers = current_account.agent_computers
      .includes(account_user: :user)
      .order(created_at: :desc)

    if params[:search].present?
      search = "%#{params[:search]}%"
      @agent_computers = @agent_computers
        .joins(account_user: :user)
        .where("agent_computers.name ILIKE :search OR users.email ILIKE :search", search: search)
    end

    if params[:created_by_id].present?
      @agent_computers = @agent_computers.where(account_users: { user_id: params[:created_by_id] })
    end

    if params[:status].present?
      @agent_computers = @agent_computers.where(status: params[:status])
    end

    @pagy, @agent_computers = pagy(@agent_computers)
  end

  # A computer opens on its tasks; its machine (status, resources, access commands) is on edit
  def show
    redirect_to agent_computer_agent_posts_path(@agent_computer)
  end

  def edit
  end

  def update
    if @agent_computer.update(model_params)
      redirect_to edit_agent_computer_path(@agent_computer), notice: "Model settings saved."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def new
    @agent_computer = AgentComputer.new
    @clusters = available_clusters
  end

  # The cluster comes from the ones this person can use, never straight from the request: any id would otherwise
  # put a VM on another account's cluster, with that account's kubeconfig
  def create
    @agent_computer = current_account_user.agent_computers.new(model_params.merge(name: params.dig(:agent_computer, :name)))
    @agent_computer.cluster = available_clusters.find_by(id: params.dig(:agent_computer, :cluster_id))

    if @agent_computer.save
      AgentComputers::ProvisionJob.perform_later(@agent_computer)
      redirect_to edit_agent_computer_path(@agent_computer), notice: "Computer is being provisioned."
    else
      @clusters = available_clusters
      render :new, status: :unprocessable_entity
    end
  end

  def destroy
    AgentComputers::DestroyJob.perform_later(@agent_computer)
    redirect_to agent_computers_path, status: :see_other, notice: "Computer is being destroyed."
  end

  def stop
    return redirect_to(edit_agent_computer_path(@agent_computer), alert: "Computer must be running to stop it.") unless @agent_computer.running?

    @agent_computer.stopping!
    AgentComputers::StopJob.perform_later(@agent_computer)
    redirect_to edit_agent_computer_path(@agent_computer), notice: "Computer is shutting down. Its files are kept."
  end

  def start
    return redirect_to(edit_agent_computer_path(@agent_computer), alert: "Computer must be stopped to start it.") unless @agent_computer.stopped?

    @agent_computer.starting!
    AgentComputers::StartJob.perform_later(@agent_computer)
    redirect_to edit_agent_computer_path(@agent_computer), notice: "Computer is starting."
  end

  def connect
    render layout: "fullscreen"
  end

  # Loaded lazily into a turbo frame on the overview, since it shells out to the cluster several times
  def stats
    @stats = AgentComputers::Stats.new(@agent_computer, current_user).fetch if @agent_computer.running?
    render layout: false
  rescue StandardError => e
    Rails.logger.error("Failed to fetch stats for computer #{@agent_computer.id}: #{e.message}")
    @error = e.message
    render layout: false
  end

  private

  def require_running
    redirect_to edit_agent_computer_path(@agent_computer), alert: "Computer must be running." unless @agent_computer.running?
  end

  def set_agent_computer
    @agent_computer = current_account.agent_computers.find(params[:id])
  end

  # Clusters this person can see (teams can restrict them) that can run agent computers
  def available_clusters
    Clusters::VisibleToUser.execute(account_user: current_account_user).clusters.running.with_agent_computer.order(:name)
  end

  # What can change after create: a computer's name and cluster are fixed (its namespace and VM live there)
  def model_params
    params.require(:agent_computer).permit(:planning_model, :browse_model, :coding_model, :coding_agent)
  end
end
