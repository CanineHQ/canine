class ShellSessionsController < ApplicationController
  def destroy
    session = ShellToken.where(user: current_user).connected.find(params[:id])
    session.destroy

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: [
          turbo_stream.remove("shell_session_#{params[:id]}"),
          turbo_stream.replace("session_count", partial: "projects/workbenches/session_count")
        ]
      end
      format.html { redirect_back fallback_location: root_path, notice: "Session terminated." }
    end
  end
end
