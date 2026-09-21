module AgentSandboxes
  class ProvisionJob < ApplicationJob
    queue_as :default

    def perform(agent_sandbox)
      agent_sandbox.provisioning!

      cluster = agent_sandbox.cluster
      user = agent_sandbox.user
      connection = K8::Connection.new(cluster, user)
      kubectl = K8::Kubectl.new(connection, Cli::RunAndLog.new(cluster))

      yaml_content = build_sandbox_yaml(agent_sandbox)
      kubectl.apply_yaml(yaml_content)

      agent_sandbox.running!
    rescue StandardError => e
      agent_sandbox.failed!
      Rails.logger.error("Failed to provision agent sandbox #{agent_sandbox.id}: #{e.message}")
      raise
    end

    private

    def build_sandbox_yaml(agent_sandbox)
      {
        "apiVersion" => "agents.x-k8s.io/v1beta1",
        "kind" => "Sandbox",
        "metadata" => {
          "name" => agent_sandbox.name,
          "namespace" => "default"
        },
        "spec" => {
          "podTemplate" => {
            "metadata" => {
              "labels" => {
                "sandbox" => agent_sandbox.name,
                "app.kubernetes.io/managed-by" => "canine"
              }
            },
            "spec" => {
              "containers" => [
                {
                  "name" => "aio-sandbox",
                  "image" => "ghcr.io/agent-infra/sandbox:1.0.0.152",
                  "securityContext" => {
                    "allowPrivilegeEscalation" => false
                  },
                  "ports" => [
                    { "containerPort" => 8080 }
                  ],
                  "resources" => {
                    "limits" => {
                      "memory" => "4Gi",
                      "cpu" => "2000m"
                    }
                  }
                }
              ]
            }
          }
        }
      }.to_yaml
    end
  end
end
