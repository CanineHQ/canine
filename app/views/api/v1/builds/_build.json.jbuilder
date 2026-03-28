# frozen_string_literal: true

json.merge! Api::Builds::ShowViewModel.new(build).as_json
