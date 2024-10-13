class AddOns::LogsController < AddOns::BaseController
  def index
    @pods = get_pods_for_add_on(@add_on)
  end

  def show
    client = K8::Client.new(@add_on.cluster.kubeconfig)
    @logs = client.get_pod_log(params[:id], @add_on.name)
  end

  private

  def get_pods_for_add_on(add_on)
    client = K8::Client.new(add_on.cluster.kubeconfig).client
    client.get_pods(namespace: add_on.name)
  end
end
