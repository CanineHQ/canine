# frozen_string_literal: true

module Clusters
  class Filter
    extend LightService::Action

    expects :params, :clusters
    promises :clusters

    executed do |context|
      query = context.params[:q].to_s.strip

      if query.present?
        context.clusters = context.clusters.where("clusters.name ILIKE ?", "%#{query}%")
      end
    end
  end
end
