# frozen_string_literal: true

json.add_ons Api::AddOns::ListViewModel.new(@add_ons).as_json
