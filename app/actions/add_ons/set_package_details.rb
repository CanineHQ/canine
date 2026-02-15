class AddOns::SetPackageDetails
  extend LightService::Action
  expects :add_on

  executed do |context|
    add_on = context.add_on
    result = AddOns::FetchChartDetailsFromArtifactHub.execute(chart_url: add_on.chart_url)

    if result.failure?
      add_on.errors.add(:base, "Failed to fetch package details")
      context.fail_and_return!("Failed to fetch package details")
    end

    # Readme is too large
    result.response.delete('readme')
    add_on.metadata['package_details'] = result.response
    add_on.version ||= result.response['version']
  end
end
