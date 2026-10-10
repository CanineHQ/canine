# frozen_string_literal: true

# Searches curated charts and Artifact Hub for Helm charts that can be installed as add-ons.
module Api
  module AddOns
    class Search
      extend LightService::Action
      expects :query
      promises :results

      executed do |context|
        query = context.query.to_s.downcase
        search = ::AddOns::HelmChartSearch.execute(query: context.query)
        context.fail_and_return!("Failed to search Artifact Hub") unless search.success?

        curated = K8::Helm::Client::CHARTS["helm"]["charts"].select do |chart|
          chart["name"].include?(query) || chart["display_name"]&.downcase&.include?(query)
        end

        hub_packages = (search.response&.fetch("packages", nil) || []).first(15)

        context.results = {
          curated: curated.map { |chart| Api::HelmCharts::CuratedViewModel.new(chart).as_json },
          artifact_hub: hub_packages.map { |pkg| Api::HelmCharts::HubResultViewModel.new(pkg).as_json }
        }
      end
    end
  end
end
