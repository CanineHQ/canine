# Agent sessions on an agent computer: the list, and one session's live timeline (it updates over Turbo Streams as
# the session runs; see the broadcasts in AgentSession and its steps and actions).
class AgentSessionsController < ApplicationController
  include AgentTasksFeature

  before_action :set_agent_computer

  # Runs are listed on their task's page
  def index
    redirect_to agent_computer_agent_tasks_path(@agent_computer)
  end

  def show
    @session = @agent_computer.agent_sessions.find(params[:id])
  end

  # Every screenshot in the session, in order, for the lightbox: small to fetch, however many there are
  def screenshots
    session = @agent_computer.agent_sessions.find(params[:id])
    actions = session.actions.joins(:screenshot_attachment).includes(:activity, screenshot_attachment: :blob)
    render json: actions.map { |action|
      { id: action.id, src: rails_blob_path(action.screenshot, disposition: "inline"),
        caption: "#{action.activity.title} · #{action.label} · #{action.created_at.strftime("%H:%M:%S")}" }
    }
  end

  def cancel
    session = @agent_computer.agent_sessions.find(params[:id])
    session.finish!(:cancelled, error: "Cancelled by #{current_user.email}.") if session.active?
    redirect_to agent_computer_agent_session_path(@agent_computer, session)
  end

  private

  def set_agent_computer
    @agent_computer = current_account.agent_computers.find(params[:agent_computer_id])
  end
end
