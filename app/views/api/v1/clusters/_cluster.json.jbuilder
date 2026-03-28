# frozen_string_literal: true

json.merge! Api::Clusters::ShowViewModel.new(cluster).as_json
