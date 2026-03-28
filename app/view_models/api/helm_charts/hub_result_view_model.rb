# frozen_string_literal: true

module Api
  module HelmCharts
    class HubResultViewModel
      def initialize(package)
        @package = package
      end

      def as_json
        repo = @package["repository"] || {}
        {
          name: @package["name"],
          description: @package["description"],
          chart_url: "#{repo["name"]}/#{@package["name"]}",
          repository_url: repo["url"],
          version: @package["version"],
          artifact_hub_package_id: "helm/#{repo["name"]}/#{@package["name"]}",
          curated: false
        }
      end
    end
  end
end
