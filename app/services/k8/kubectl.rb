# frozen_string_literal: true

class K8::Kubectl
  attr_reader :connection, :runner

  def initialize(connection, runner = Cli::RunAndReturnOutput.new)
    @connection = connection
    if connection.kubeconfig.nil?
      raise "Kubeconfig is required"
    end
    @runner = runner
    @before_apply_blocks = []
    @after_apply_blocks = []
  end

  def register_before_apply(&block)
    @before_apply_blocks << block
  end

  def register_after_apply(&block)
    @after_apply_blocks << block
  end

  def apply_yaml(yaml_content)
    @before_apply_blocks.each do |block|
      block.call(yaml_content)
    end

    K8::Kubeconfig.with_kube_config(connection.kubeconfig, skip_tls_verify: connection.cluster.skip_tls_verify) do |kubeconfig_file|
      # Create a temporary file for the YAML content
      Tempfile.open([ "k8s", ".yaml" ]) do |yaml_file|
        yaml_file.write(yaml_content)
        yaml_file.flush

        # Apply the YAML file to the cluster using the kubeconfig file
        command = "kubectl apply -f #{yaml_file.path}"
        runner.call(command, envs: { "KUBECONFIG" => kubeconfig_file.path })
      end
    end

    @after_apply_blocks.each do |block|
      block.call(yaml_content)
    end
  end

  def call(command)
    K8::Kubeconfig.with_kube_config(connection.kubeconfig, skip_tls_verify: connection.cluster.skip_tls_verify) do |kubeconfig_file|
      full_command = "kubectl #{command}"
      runner.call(full_command, envs: { "KUBECONFIG" => kubeconfig_file.path })
    end
  end
end
