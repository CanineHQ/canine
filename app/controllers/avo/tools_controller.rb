class Avo::ToolsController < Avo::ApplicationController
  helper AvoDashboardHelper

  def dashboard
    @page_title = "Dashboard"
    add_breadcrumb "Dashboard"
  end
end
