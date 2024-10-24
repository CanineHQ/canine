class EnvironmentVariables::BulkUpdate
  extend LightService::Action

  expects :project, :params
  expects :current_user, default: nil

  executed do |context|
    project = context.project
    env_variable_data = context.params[:environment_variables]

    incoming_variable_names = env_variable_data.map { |ev| ev[:name] }
    current_variable_names = project.environment_variables.pluck(:name)

    new_names = incoming_variable_names - current_variable_names

    if new_names.any?
      env_variable_data.filter { |ev| new_names.include?(ev[:name]) }.each do |ev|
        next if ev[:name].blank?
        project.environment_variables.create!(
          name: ev[:name].strip.upcase,
          value: ev[:value].strip,
          current_user: context.current_user
        )
      end
    end

    destroy_names = current_variable_names - incoming_variable_names

    project.environment_variables.where(name: destroy_names).destroy_all if destroy_names.any?
  end
end
