class AgentComputersController < ApplicationController
  before_action :set_agent_computer, only: %i[show destroy connect control stats]
  before_action :require_running, only: %i[connect control]

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

  def show
  end

  def new
    @agent_computer = AgentComputer.new
    @clusters = current_account.clusters.running.with_agent_computer.order(:name)
  end

  def create
    @agent_computer = AgentComputer.new(agent_computer_params)
    @agent_computer.account_user = current_account_user

    if @agent_computer.save
      AgentComputers::ProvisionJob.perform_later(@agent_computer)
      redirect_to @agent_computer, notice: "Computer is being provisioned."
    else
      @clusters = current_account.clusters.running.with_agent_computer.order(:name)
      render :new, status: :unprocessable_entity
    end
  end

  def destroy
    AgentComputers::DestroyJob.perform_later(@agent_computer)
    redirect_to agent_computers_path, status: :see_other, notice: "Computer is being destroyed."
  end

  def connect
    render layout: "fullscreen"
  end

  def control
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
    redirect_to @agent_computer, alert: "Computer must be running." unless @agent_computer.running?
  end

  def set_agent_computer
    @agent_computer = current_account.agent_computers.find(params[:id])
  end

  def agent_computer_params
    params.require(:agent_computer).permit(:name, :cluster_id)
  end
end
