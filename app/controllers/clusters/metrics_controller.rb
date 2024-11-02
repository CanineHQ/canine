class Clusters::MetricsController < Clusters::BaseController
  include MetricsHelper
  include StorageHelper
  before_action :set_cluster

  def show
    @nodes = K8::Metrics::Api::Node.ls(@cluster)
  end
end
