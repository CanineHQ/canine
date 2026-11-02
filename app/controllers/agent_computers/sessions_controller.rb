# Agent sessions on an agent computer: the list, and one session's live timeline (it updates over Turbo Streams as
# the session runs; see the broadcasts in AgentComputer::Session and its steps and actions).
class AgentComputers::SessionsController < AgentComputers::BaseController
  # Runs are listed on their task's page
  def index
    redirect_to agent_computer_agent_tasks_path(@agent_computer)
  end

  def show
    @session = @agent_computer.sessions.find(params[:id])
  end

  # Every screenshot in the session, in order, for the lightbox: small to fetch, however many there are
  def screenshots
    session = @agent_computer.sessions.find(params[:id])
    actions = session.actions.joins(:screenshot_attachment).includes(:activity, screenshot_attachment: :blob)
    render json: actions.map { |action|
      { id: action.id, src: rails_blob_path(action.screenshot, disposition: "inline"),
        caption: "#{action.activity.title} · #{action.label} · #{action.created_at.strftime("%H:%M:%S")}", explainer: action.explainer }
    }
  end

  # The person's answer to the question a run paused on (ask_person): it carries on with it
  def answer
    session = @agent_computer.sessions.find(params[:id])
    answer = params[:answer].to_s.strip
    if answer.blank?
      flash[:alert] = "Type an answer first."
    elsif !session.answer!(answer)
      flash[:alert] = "That run isn't waiting for an answer any more."
    end
    redirect_back fallback_location: agent_computer_agent_session_path(@agent_computer, session), status: :see_other
  end

  def cancel
    session = @agent_computer.sessions.find(params[:id])
    session.finish!(:cancelled, error: "Cancelled by #{current_user.email}.") if session.active?
    redirect_back fallback_location: agent_computer_agent_session_path(@agent_computer, session), status: :see_other
  end
end
