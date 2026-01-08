class AddOns::HelmChartValuesSchema
  extend LightService::Action
  expects :package_id, :version
  promises :schema

  executed do |context|
    response = HTTParty.get(
      "https://artifacthub.io/api/v1/packages/#{context.package_id}/#{context.version}/values-schema"
    )

    if response.success?
      context.schema = response.parsed_response
    else
      context.fail_and_return!("No values schema available: #{response.code}")
    end
  end
end
