class AddOns::Create
  extend LightService::Action
  expects :add_on
  promises :add_on

  executed do |context|
    add_on = context.add_on
    apply_template_to_values(add_on)
    fetch_package_details(context, add_on)
    unless add_on.save
      context.fail_and_return!("Failed to create add on")
    end
  end

  def self.fetch_package_details(context, add_on)
    result = AddOns::HelmChartDetails.execute(chart_url: add_on.chart_url)

    if result.failure?
      add_on.errors.add(:base, "Failed to fetch package details")
      context.fail_and_return!("Failed to fetch package details")
    end

    result.response.delete('readme')
    add_on.metadata['package_details'] = result.response
  end

  def self.apply_template_to_values(add_on)
    # Merge the values from the form with the values.yaml object and create a new values.yaml file
    add_on.values.extend(DotSettable)

    variables = add_on.metadata['template'] || {}
    variables.keys.each do |key|
      variable = variables[key]

      if variable.is_a?(Hash) && variable['type'] == 'size'
        add_on.values.dotset(key, "#{variable['value']}#{variable['unit']}")
      else
        variable_definition = add_on.chart_definition['template'].find { |t| t['key'] == key }
        if variable_definition['type'] == 'integer'
          add_on.values.dotset(key, variable.to_i)
        else
          add_on.values.dotset(key, variable)
        end
      end
    end
  end
end
