# frozen_string_literal: true

json.merge! Api::AddOns::ShowViewModel.new(add_on, @service).as_json
