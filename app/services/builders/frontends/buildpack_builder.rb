# frozen_string_literal: true

class Builders::Frontends::BuildpackBuilder
  attr_accessor :build, :project

  def initialize(build)
    @build = build
    @project = build.project
  end

  # Build image using Cloud Native Buildpacks
  def build_with_buildpacks(repository_path)
    build_config = build.project.build_configuration

    build.info("Building with Cloud Native Buildpacks", color: :blue)
    build.info("Builder: #{build_config.buildpack_base_builder}", color: :cyan)
    build.info("Context: #{build_config.context_directory}", color: :cyan)

    # Log buildpacks in order
    if build_config.build_packs.any?
      build.info("Buildpacks:", color: :cyan)
      build_config.build_packs.each do |pack|
        verified_badge = pack.verified? ? " [verified]" : ""
        build.info("  #{pack.build_order + 1}. #{pack.reference}#{verified_badge}")
      end
    else
      build.info("No buildpacks specified - builder will auto-detect", color: :yellow)
    end

    # Generate and execute pack command
    report_dir = File.join(repository_path, "pack-report")
    FileUtils.mkdir_p(report_dir)
    command = generate_pack_command(repository_path, build_config, report_dir: report_dir)

    build.info("Running pack build...", color: :green)
    run_pack_command(command)

    # Push image if not published during build
    push_image_after_build unless publish_during_build?

    parse_digest_from_report(report_dir)
  end

  private

  def generate_pack_command(repository_path, build_config, report_dir: nil)
    image_name = build_config.container_image_reference
    context_path = File.join(repository_path, build_config.context_directory)

    command = [
      "pack", "build", image_name,
      "--builder", build_config.buildpack_base_builder,
      "--path", context_path
    ]

    # Add buildpacks in order
    build_config.build_packs.each do |pack|
      command += [ "--buildpack", pack.reference ]
    end

    # Add publish flag if supported by driver
    command << "--publish" if publish_during_build?

    # Add pull policy to always pull latest builder
    command += [ "--pull-policy", "always" ]

    # Trust builder (required for some builders)
    command << "--trust-builder"

    command += [ "--report-output-dir", report_dir ] if report_dir

    command.shelljoin
  end

  def run_pack_command(command)
    runner = Cli::RunAndLog.new(build, killable: build)
    runner.call(command)
  rescue Cli::CommandFailedError => e
    raise Projects::BuildJob::BuildFailure, "Pack build failed: #{e.message}"
  end

  # Override in including class if push happens during build
  def publish_during_build?
    false
  end

  # Override in including class to implement image push logic
  def push_image_after_build
    # Default: assume publish_during_build? is true
    # Concrete builders should override if they need separate push
  end

  def parse_digest_from_report(report_dir)
    report_file = File.join(report_dir, "report.toml")
    return nil unless File.exist?(report_file)

    content = File.read(report_file)
    match = content.match(/image-id\s*=\s*"([^"]+)"/)
    return nil unless match

    image_id = match.captures.first
    image_id.start_with?("sha256:") ? image_id : "sha256:#{image_id}"
  end
end
