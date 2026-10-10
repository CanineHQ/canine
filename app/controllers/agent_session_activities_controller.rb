# An activity's contents (its narration, actions and screenshots), loaded when someone opens it on the session page,
# so a long session's page doesn't load everything up front
class AgentSessionActivitiesController < ApplicationController
  include AgentTasksFeature

  def show
    computer = current_account.agent_computers.find(params[:agent_computer_id])
    @activity = computer.agent_sessions.find(params[:agent_session_id]).activities
      .includes(actions: { screenshot_attachment: :blob }).find(params[:id])
    render partial: "agent_sessions/activity_body", locals: { activity: @activity, lazy: true }
  end
end
