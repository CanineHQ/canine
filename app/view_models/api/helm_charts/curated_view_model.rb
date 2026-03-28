# frozen_string_literal: true

module Api
  module HelmCharts
    class CuratedViewModel
      def initialize(chart)
        @chart = chart
      end

      def as_json
        {
          name: @chart["display_name"] || @chart["name"],
          chart_url: @chart["chart_url"],
          repository_url: @chart["repository_url"],
          curated: true,
          template: @chart["template"]&.map do |t|
            { name: t["name"], key: t["key"], type: t["type"], default: t["default"] }
          end
        }
      end
    end
  end
end
