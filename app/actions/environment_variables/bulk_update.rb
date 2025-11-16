class EnvironmentVariables::BulkUpdate
  extend LightService::Action

  expects :project, :params
  expects :current_user, default: nil

  executed do |context|
    project = context.project
    ActiveRecord::Base.transaction do
      env_variable_data = context.params[:environment_variables] || []

      incoming_variable_names = env_variable_data.map { |ev| ev[:name] }
      current_variable_names = project.environment_variables.pluck(:name)

      new_names = incoming_variable_names - current_variable_names

      if new_names.any?
        env_variable_data.filter { |ev| new_names.include?(ev[:name]) }.each do |ev|
          next if ev[:name].blank?
          project.environment_variables.create!(
            name: ev[:name].strip.upcase,
            value: ev[:value].strip,
            storage_type: ev[:storage_type] || :config,
            current_user: context.current_user
          )
        end
      end

      destroy_names = current_variable_names - incoming_variable_names
      project.environment_variables.where(name: destroy_names).destroy_all

      updated_variables = project.environment_variables.where(name: incoming_variable_names)

      updated_variables.each do |ev|
        env_variable = env_variable_data.find { |evd| evd[:name] == ev.name }
        # Skip updating value if keep_existing_value flag is set
        if env_variable[:keep_existing_value] == "true"
          update_attrs = {}
        else
          update_attrs = {}
          update_attrs[:value] = env_variable[:value].strip if env_variable[:value] != ev.value
        end
        update_attrs[:storage_type] = env_variable[:storage_type] if env_variable[:storage_type] && env_variable[:storage_type] != ev.storage_type


        if update_attrs.any?
          ev.update!(
            **update_attrs,
            current_user: context.current_user
          )
          ev.events.create!(
            user: context.current_user,
            event_action: :update,
            project: project
          )
        end
      end
    end
  rescue => e
    context.fail!(e.message)
  end
end
