# frozen_string_literal: true

require 'open3'

module Builders
  class Docker < Builders::Base
    # Build and push the Docker image
    def build_image(repository_path)
      if project.build_configuration.buildpacks?
        Builders::Frontends::BuildpackBuilder.new(build).build_with_buildpacks(repository_path)
      else
        Builders::Frontends::DockerfileBuilder.new(build).build_with_dockerfile(repository_path)
      end
    end

    private

    # Pack publishes during build with --publish flag
    def publish_during_build?
      true
    end
  end
end
