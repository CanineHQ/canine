class Projects::AddDomainJob < ApplicationJob
  def perform(cluster)
    runner = Cli::RunAndLog.new(cluster)
    K8::Kubectl.new(cluster.kubeconfig).apply_yaml(K8::Shared::Ingress.new(cluster).to_yaml)
  end
end