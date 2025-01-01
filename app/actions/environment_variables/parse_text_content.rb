class EnvironmentVariables::ParseTextContent
  extend LightService::Action

  expects :params
  promises :params

  executed do |context|
    unless context.params[:text_content].present?
      next
    end

    context.params[:environment_variables] = context.params[:text_content].strip.split("\n").map do |line|
      name, value = line.split("=")
      # If the value is in quotes, remove them
      value = value.gsub(/^"|"$/, "") if value.present?
      { name:, value: }
    end
  end
end
