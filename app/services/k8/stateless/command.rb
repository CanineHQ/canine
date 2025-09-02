class K8::Stateless::Command < K8::Base
  attr_accessor :project, :type, :command

  def initialize(project, type, command)
    @project = project
    @type = type
    @command = command
  end

  def name
    "#{project.name}-#{type}"
  end

  def namespace
    project.name
  end

  def delete_if_exists!
    return if kubectl.call("get job #{name} -n #{namespace}").strip.empty?
    kubectl.call("delete job #{name} -n #{namespace}")
  rescue StandardError => e
    nil
  end

  def wait_for_completion
    retries = 0
    while true
      break if done?
      sleep(3.0)
      retries += 1
      if retries > 30
        raise Projects::DeploymentJob::DeploymentFailure, "Predeploy command `#{command}` took too long to complete"
      end
    end
  end

  def done?
    _statuses = statuses
    if _statuses.include?("Failed") || _statuses.include?("ActiveDeadlineExceeded")
      raise Projects::DeploymentJob::DeploymentFailure, "Predeploy command `#{command}` failed"
    end
    _statuses.include?("Complete")
  end

  def statuses
    begin
      output = kubectl.call("get job #{name} -n #{namespace} -o jsonpath='{.status.conditions[*].type}'")
      conditions = output.split
      conditions.map { |condition| condition.strip }
    rescue => e
      Rails.logger.error("Error checking job completion: #{e.message}")
      false
    end
  end
end
