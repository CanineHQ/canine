# frozen_string_literal: true

json.projects @projects, partial: 'api/v1/projects/project', as: :project
