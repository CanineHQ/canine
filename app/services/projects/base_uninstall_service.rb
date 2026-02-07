class Projects::BaseUninstallService
  def initialize(project, user)
    @project = project
    @user = user
    @logger = project.cluster
  end

  def call
    setup_connection

    predestroy
    uninstall_resources
    postdestroy

    delete_namespace if @project.managed_namespace?
    @logger.info("Uninstalled #{@project.name}", color: :green)
  end

  private

  def setup_connection
    @connection = K8::Connection.new(@project, @user, allow_anonymous: true)
    @kubectl = K8::Kubectl.new(@connection)
  end

  def uninstall_resources
    raise NotImplementedError, "Subclasses must implement #uninstall_resources"
  end

  def predestroy
    return unless @project.predestroy_command.present?

    run_command(@project.predestroy_command, "predestroy")
  end

  def postdestroy
    return unless @project.postdestroy_command.present?

    run_command(@project.postdestroy_command, "postdestroy")
  end

  def run_command(command, type)
    @logger.info("Running command: `#{command}`...", color: :yellow)
    command_job = K8::Stateless::Command.new(@project, type, command).connect(@connection)
    command_job.delete_if_exists!
    @kubectl.apply_yaml(command_job.to_yaml)
    command_job.wait_for_completion
  end

  def delete_namespace
    @logger.info("Deleting namespace: #{@project.namespace}", color: :yellow)
    @kubectl.call("delete namespace #{@project.namespace} --ignore-not-found")
  end
end
