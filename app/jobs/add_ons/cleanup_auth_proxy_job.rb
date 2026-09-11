class AddOns::CleanupAuthProxyJob < ApplicationJob
  def perform(add_on)
    connection = K8::Connection.new(add_on, nil, allow_anonymous: true)
    kubectl = K8::Kubectl.new(connection)

    # Find and delete all auth-proxy labeled resources in the add-on namespace
    %w[deployment service].each do |resource_type|
      result = kubectl.call(%w[-n] + [ add_on.name, "get", resource_type, "-l", "caninemanaged=auth-proxy", "-o", "name" ])
      result.to_s.split("\n").each do |resource_name|
        kubectl.call(%w[-n] + [ add_on.name, "delete", resource_name, "--ignore-not-found" ]) if resource_name.present?
      end
    end
  end
end
