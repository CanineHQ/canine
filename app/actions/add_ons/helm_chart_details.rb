class AddOns::HelmChartDetails
  Package = Struct.new(:chart_url, :response) do
  end
  extend LightService::Action
  expects :chart_url
  promises :response

  executed do |context|
    response = HTTParty.get("https://artifacthub.io/api/v1/packages/helm/#{context.chart_url}")
    if response.success?
      context.response = response.parsed_response
    else
      context.fail_and_return!("Failed to fetch package details: #{response.code}: #{response.message}")
    end
  end
end
