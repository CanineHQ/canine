class EnvironmentVariables::BulkUpdate
  extend LightService::Action

  expects :project, :params

  executed do |context|
    project = context.project
    # Delete all environment variables and create new ones

    project.environment_variables.destroy_all

    (context.params[:environment_variables] || []).each do |environment_variable_params|
      next if environment_variable_params[:name].blank?
      name = environment_variable_params[:name].strip.upcase
      value = environment_variable_params[:value].strip
      project.environment_variables.create!(name:, value:)
    end
  end
end