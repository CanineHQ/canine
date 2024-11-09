class Projects::Local::CheckDockerExists
  extend LightService::Action

  expects :checklist
  promises :checklist

  executed do |context|
    # Check if docker binary exists in PATH
    context.checklist << "Checking docker binary exists..."
    unless system('which docker > /dev/null 2>&1')
      context.fail!("Docker is not installed or not in PATH")
      return
    end

    # Check if current user can run docker commands
    context.checklist << "Checking current user can run docker commands..."
    unless system('docker info > /dev/null 2>&1')
      context.fail!("Cannot access Docker. Please ensure the current user has proper permissions")
      return
    end

    # Get Docker version and check if it meets minimum requirements
    context.checklist << "Checking Docker version..."
    version_output = `docker version --format '{{.Server.Version}}' 2>/dev/null`
    if $?.success?
      current_version = Gem::Version.new(version_output.strip)
      minimum_version = Gem::Version.new('20.10.0') # Adjust minimum version as needed

      if current_version < minimum_version
        context.fail!("Docker version #{current_version} is below minimum required version #{minimum_version}")
        return
      end
    else
      context.fail!("Unable to determine Docker version")
      return
    end
  end
end