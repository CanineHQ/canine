class Projects::MetricsController < Projects::BaseController
  include NamespaceMetricsHelper

  def index
    configure(@project)
  end
end
