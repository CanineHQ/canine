class Builders::Frontends::DockerfileBuilder
  attr_accessor :build, :project

  def initialize(build)
    @build = build
    @project = build.project
  end

  def build_with_dockerfile(repository_path)
    metadata_file = File.join(repository_path, "buildx-metadata.json")
    docker_build_command = construct_buildx_command(repository_path, metadata_file: metadata_file)

    # Create a new instance of RunAndLog with the build object as the loggable and killable
    runner = Cli::RunAndLog.new(build, killable: build)

    # Call the runner with the command (joined as a string since RunAndLog expects a string)
    runner.call(docker_build_command.join(" "))

    parse_digest_from_metadata(metadata_file)
  rescue Cli::CommandFailedError => e
    raise "Docker build failed: #{e.message}"
  end

  def construct_buildx_command(repository_path, metadata_file: nil)
    docker_build_command = [
      "docker",
      "--context=default",
      "buildx",
      "build",
      "--progress=plain",
      "--platform", "linux/amd64,linux/arm64",
      "-t", project.container_image_reference,
      "-f", File.join(repository_path, project.build_configuration.dockerfile_path)
    ]

    # Add environment variables to the build command
    project.environment_variables.each do |envar|
      docker_build_command.push("--build-arg", "#{envar.name}=\"#{envar.value}\"")
    end

    docker_build_command.push("--push")

    docker_build_command.push("--metadata-file", metadata_file) if metadata_file

    # Add the build context directory at the end
    docker_build_command.push(File.join(repository_path, project.build_configuration.context_directory))
    Rails.logger.info("Docker build command: `#{docker_build_command.join(" ")}`")
    docker_build_command
  end

  private

  def parse_digest_from_metadata(metadata_file)
    return nil unless File.exist?(metadata_file)

    metadata = JSON.parse(File.read(metadata_file))
    metadata["containerimage.digest"]
  rescue JSON::ParserError
    nil
  end
end
