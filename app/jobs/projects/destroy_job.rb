
class Projects::DestroyJob < ApplicationJob

  def perform(project)
    project.destroying!
    kubeconfig = project.cluster.kubeconfig
    kubectl = K8::Kubectl.new(kubeconfig)

    kubectl.call("delete namespace #{project.name}")

    project.destroy!
  end
end
