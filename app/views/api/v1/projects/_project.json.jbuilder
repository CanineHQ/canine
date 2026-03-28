# frozen_string_literal: true

json.merge! Api::Projects::ListViewModel.new(project).as_json
