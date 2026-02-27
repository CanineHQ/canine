class CanineConfig::Definition
  attr_reader :definition

  def self.parse(yaml_content, base_project, pull_request)
    context = build_context(base_project, pull_request)

    # Use safe variable substitution instead of ERB to prevent code execution
    parsed_content = if yaml_content.include?('<%')
      safe_template_replace(yaml_content, context)
    else
      yaml_content
    end

    new(YAML.safe_load(parsed_content))
  end

  def self.safe_template_replace(template, variables)
    # Only allow simple variable substitution: <%= variable_name %>
    # No code execution, method calls, or complex expressions
    template.gsub(/<%=\s*(\w+)\s*%>/) do |match|
      variable_name = $1
      # Convert string keys to symbols if needed, or vice versa
      value = variables[variable_name.to_sym] || variables[variable_name.to_s] || variables[variable_name]

      if value.nil?
        # Keep the original placeholder if variable not found
        # This helps with debugging and makes missing variables obvious
        match
      else
        value.to_s
      end
    end
  end

  def self.build_context(base_project, pull_request)
    {
      "cluster_id": base_project.project_fork_cluster_id,
      "cluster_name": base_project.project_fork_cluster.name,
      "project_name": "#{base_project.name}-#{pull_request.number}",
      "number": pull_request.number,
      "title": pull_request.title,
      "branch_name": pull_request.branch,
      "username": pull_request.user
    }
  end

  def initialize(definition)
    @definition = definition
  end

  def predeploy_command
    definition.dig('scripts', 'predeploy')
  end

  def postdeploy_command
    definition.dig('scripts', 'postdeploy')
  end

  def predestroy_command
    definition.dig('scripts', 'predestroy')
  end

  def postdestroy_command
    definition.dig('scripts', 'postdestroy')
  end

  def services
    return [] if definition['services'].blank?

    definition['services'].map do |service|
      params = Service.permitted_params(ActionController::Parameters.new(service:))
      service_instance = Service.new(params)

      # Handle domains if present and service is a web_service
      if service['service_type'] == 'web_service' && service['domains'].present?
        service_instance.allow_public_networking = true

        service['domains'].each do |domain|
          domain_attrs = domain.is_a?(Hash) ? domain : { domain_name: domain }
          service_instance.domains.build(domain_attrs)
        end
      end

      # Handle nested resource_constraint
      if service['resource_constraint'].present?
        service_instance.build_resource_constraint(service['resource_constraint'])
      end

      # Handle nested cron_schedule
      if service['cron_schedule'].present?
        service_instance.build_cron_schedule(service['cron_schedule'])
      end

      service_instance
    end
  end

  def environment_variables
    return [] if definition['environment_variables'].blank?

    definition['environment_variables'].map do |env|
      EnvironmentVariable.new(
        name: env['name'],
        value: env['value'],
        storage_type: env['storage_type'] || 'config'
      )
    end
  end

  def volumes
    return [] if definition['volumes'].blank?

    definition['volumes'].map do |vol|
      Volume.new(
        name: vol['name'],
        size: vol['size'],
        mount_path: vol['mount_path'],
        access_mode: vol['access_mode'] || 'read_write_once'
      )
    end
  end

  def notifiers
    return [] if definition['notifiers'].blank?

    definition['notifiers'].map do |notifier|
      Notifier.new(
        name: notifier['name'],
        provider_type: notifier['provider_type'],
        webhook_url: notifier['webhook_url'],
        enabled: notifier.fetch('enabled', true)
      )
    end
  end

  def to_hash
    @definition
  end
end
