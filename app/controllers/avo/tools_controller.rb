class Avo::ToolsController < Avo::ApplicationController
  def dashboard
    @page_title = "Dashboard"
    add_breadcrumb "Dashboard"
  end
end
