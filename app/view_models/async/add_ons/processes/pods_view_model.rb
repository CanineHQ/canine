class Async::AddOns::Processes::PodsViewModel < Async::BaseViewModel
  include LogColorsHelper
  expects :add_on_id

  def add_on
    @add_on ||= current_user.add_ons.find(params[:add_on_id])
  end

  def pods
    @pods ||= begin
      client = K8::Client.new(add_on.cluster.kubeconfig).client
      client.get_pods(namespace: add_on.name)
    end
  end

  def initial_render
    render "shared/components/table_skeleton"
  end


  def async_render
    render "processes/pods", locals: { pods: pods, parent: add_on, empty_message: "Nothing in this namespace" }
  end
end
