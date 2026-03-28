# frozen_string_literal: true

json.merge! Api::Projects::ShowViewModel.new(@project).as_json
