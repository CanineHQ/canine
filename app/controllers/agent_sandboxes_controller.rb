class AgentSandboxesController < ApplicationController
  before_action :set_agent_sandbox, only: %i[show destroy connect]

  def index
    @agent_sandboxes = current_account.agent_sandboxes
      .includes(account_user: :user)
      .order(created_at: :desc)

    if params[:search].present?
      search = "%#{params[:search]}%"
      @agent_sandboxes = @agent_sandboxes
        .joins(account_user: :user)
        .where("agent_sandboxes.name ILIKE :search OR users.email ILIKE :search", search: search)
    end

    if params[:created_by_id].present?
      @agent_sandboxes = @agent_sandboxes.where(account_users: { user_id: params[:created_by_id] })
    end

    if params[:status].present?
      @agent_sandboxes = @agent_sandboxes.where(status: params[:status])
    end

    @pagy, @agent_sandboxes = pagy(@agent_sandboxes)
  end

  def show
  end

  def new
    @agent_sandbox = AgentSandbox.new
    @clusters = current_account.clusters.running.with_agent_sandbox.order(:name)
  end

  def create
    @agent_sandbox = AgentSandbox.new(agent_sandbox_params)
    @agent_sandbox.account_user = current_account_user

    if @agent_sandbox.save
      AgentSandboxes::ProvisionJob.perform_later(@agent_sandbox)
      redirect_to @agent_sandbox, notice: "Sandbox is being provisioned."
    else
      @clusters = current_account.clusters.running.with_agent_sandbox.order(:name)
      render :new, status: :unprocessable_entity
    end
  end

  def destroy
    AgentSandboxes::DestroyJob.perform_later(@agent_sandbox)
    redirect_to agent_sandboxes_path, status: :see_other, notice: "Sandbox is being destroyed."
  end

  def connect
    unless @agent_sandbox.running?
      redirect_to @agent_sandbox, alert: "Sandbox must be running to connect."
      return
    end
  end

  private

  def set_agent_sandbox
    @agent_sandbox = current_account.agent_sandboxes.find(params[:id])
  end

  def agent_sandbox_params
    params.require(:agent_sandbox).permit(:name, :cluster_id)
  end
end
