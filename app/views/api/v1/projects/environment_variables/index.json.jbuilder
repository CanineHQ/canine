# frozen_string_literal: true

json.environment_variables @environment_variables do |environment_variable|
  json.merge! Api::EnvironmentVariables::ShowViewModel.new(environment_variable).as_json
end
