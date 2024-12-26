class AddOns::HelmChartDetails
  extend LightService::Action
  expects :query
  promises :response

  executed do |context|
    response = HTTParty.get("https://artifacthub.io/api/v1/packages/search?ts_query_web=#{context.query}")
    context.response = response.parsed_response
  end
end
