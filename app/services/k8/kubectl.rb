# frozen_string_literal: true

class K8::Kubectl
  include K8::Kubeconfig
  attr_reader :kubeconfig, :runner

  def initialize(connection, runner = Cli::RunAndReturnOutput.new)
    @_kubeconfig = connection.kubeconfig
    @kubeconfig = @_kubeconfig.is_a?(String) ? JSON.parse(@_kubeconfig) : @_kubeconfig
    if @kubeconfig.nil?
      raise "Kubeconfig is required"
    end
    @runner = runner
  end

  def apply_yaml(yaml_content)
    with_kube_config do |kubeconfig_file|
      # Create a temporary file for the YAML content
      Tempfile.open([ "k8s", ".yaml" ]) do |yaml_file|
        yaml_file.write(yaml_content)
        yaml_file.flush

        # Apply the YAML file to the cluster using the kubeconfig file
        command = "kubectl apply -f #{yaml_file.path}"
        runner.call(command, envs: { "KUBECONFIG" => kubeconfig_file.path })
      end
    end
  end

  def call(command)
    with_kube_config do |kubeconfig_file|
      full_command = "kubectl #{command}"
      runner.call(full_command, envs: { "KUBECONFIG" => kubeconfig_file.path })
    end
  end
end
