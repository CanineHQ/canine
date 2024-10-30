
class Projects::Services::DestroyJob < ApplicationJob
  def perform(project, service)
    kubeconfig = project.cluster.kubeconfig
    kubectl = K8::Kubectl.new(kubeconfig)

    kubectl.call("delete service #{service.name} -n #{project.name}")

    service.destroy!
  end
end
