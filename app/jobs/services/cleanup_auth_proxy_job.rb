class Services::CleanupAuthProxyJob < ApplicationJob
  def perform(service)
    project = service.project
    connection = K8::Connection.new(project, nil, allow_anonymous: true)
    kubectl = K8::Kubectl.new(connection)

    %w[deployment service].each do |resource_type|
      kubectl.call(%w[-n] + [ project.namespace, "delete", resource_type, "#{service.name}-auth-proxy", "--ignore-not-found" ])
    end
  end
end
