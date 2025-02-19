class Avo::ToolsController < Avo::ApplicationController
  def dashboard
    @page_title = "Dashboard"
    add_breadcrumb "Dashboard"
  end

  def login_as
    user = User.find(params[:id])
    sign_in(user)
    redirect_to root_path
  end
end
