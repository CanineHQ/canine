# frozen_string_literal: true

json.builds @builds, partial: 'api/v1/builds/build', as: :build
