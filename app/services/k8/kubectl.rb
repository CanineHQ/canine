# frozen_string_literal: true

class K8::Kubectl
  include K8::Kubeconfig
  attr_reader :kubeconfig, :runner

  def initialize(kubeconfig, runner: Cli::RunAndReturnOutput.new)
    @kubeconfig = kubeconfig
    if @kubeconfig.nil?
      raise 'Kubeconfig is required'
    end
    @runner = runner
  end

  def self.from_project(project)
    new(project.cluster.kubeconfig)
  end

  def apply_yaml(yaml_content)
    with_kube_config do |kubeconfig_file|
      # Create a temporary file for the YAML content
      Tempfile.open(['k8s', '.yaml']) do |yaml_file|
        yaml_file.write(yaml_content)
        yaml_file.flush

        # Apply the YAML file to the cluster using the kubeconfig file
        command = "kubectl --kubeconfig=#{kubeconfig_file.path} apply -f #{yaml_file.path}"
        runner.call(command)
      end
    end
  end

  def call(command)
    with_kube_config do |kubeconfig_file|
      full_command = "kubectl --kubeconfig=#{kubeconfig_file.path} #{command}"
      runner.call(full_command)
    end
  end
end
