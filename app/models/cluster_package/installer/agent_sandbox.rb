class ClusterPackage::Installer::AgentSandbox < ClusterPackage::Installer::Base
  MANIFEST_URL = "https://github.com/kubernetes-sigs/agent-sandbox/releases/latest/download/sandbox-with-extensions.yaml"

  def install!(kubectl)
    if agent_sandbox_present?(kubectl)
      package.cluster.info("agent-sandbox already installed, skipping", color: :yellow)
      return
    end

    kubectl.apply_yaml(fetch_manifest)
  end

  def uninstall!(kubectl)
    kubectl.(%W[delete -f #{MANIFEST_URL} --ignore-not-found])
  end

  private

  def agent_sandbox_present?(kubectl)
    kubectl.(%w[get crd sandboxes.agents.x-k8s.io])
    true
  rescue Cli::CommandFailedError
    false
  end

  def fetch_manifest
    uri = URI(MANIFEST_URL)
    response = Net::HTTP.get_response(uri)

    # Follow redirects (GitHub releases redirect)
    if response.is_a?(Net::HTTPRedirection)
      response = Net::HTTP.get_response(URI(response["location"]))
    end

    raise "Failed to download agent-sandbox manifest (#{response.code})" unless response.is_a?(Net::HTTPSuccess)

    response.body
  end
end
