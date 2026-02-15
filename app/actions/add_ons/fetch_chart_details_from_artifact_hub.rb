class AddOns::FetchChartDetailsFromArtifactHub
  Package = Struct.new(:chart_url, :response) do
  end
  extend LightService::Action
  expects :artifact_hub_package_id
  expects :version, default: nil
  promises :response

  executed do |context|
    # artifact_hub_package_id is in format: helm/repo/chart
    url = if context.version.present?
      "https://artifacthub.io/api/v1/packages/#{context.artifact_hub_package_id}/#{context.version}"
    else
      "https://artifacthub.io/api/v1/packages/#{context.artifact_hub_package_id}"
    end

    response = HTTParty.get(url)
    if response.success?
      context.response = response.parsed_response
    else
      context.fail_and_return!("Failed to fetch package details: #{response.code}: #{response.message}")
    end
  end
end
