# frozen_string_literal: true

json.clusters @clusters, partial: 'api/v1/clusters/cluster', as: :cluster
