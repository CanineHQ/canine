# An activity's contents (its narration, actions and screenshots), loaded when someone opens it on the session page,
# so a long session's page doesn't load everything up front
class AgentComputers::ActivitiesController < AgentComputers::BaseController
  def show
    @activity = @agent_computer.sessions.find(params[:agent_session_id]).activities
      .includes(actions: { screenshot_attachment: :blob }).find(params[:id])
    render partial: "agent_computers/sessions/activity_body", locals: { activity: @activity, lazy: true }
  end
end
