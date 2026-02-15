class AddOns::FetchChartDetailsFromArtifactHub
  Package = Struct.new(:chart_url, :response) do
  end
  extend LightService::Action
  expects :chart_url
  expects :version, default: nil
  promises :response

  executed do |context|
    url = if context.version.present?
      "https://artifacthub.io/api/v1/packages/helm/#{context.chart_url}/#{context.version}"
    else
      "https://artifacthub.io/api/v1/packages/helm/#{context.chart_url}"
    end

    response = HTTParty.get(url)
    if response.success?
      context.response = response.parsed_response
    else
      context.fail_and_return!("Failed to fetch package details: #{response.code}: #{response.message}")
    end
  end
end
