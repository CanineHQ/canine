class AddOns::MetricsController < AddOns::BaseController
  include NamespaceMetricsHelper
  before_action :set_add_on

  def show
    configure(@add_on)
  end
end
