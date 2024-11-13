class Projects::Local::CheckGithubConnectivity
  extend LightService::Action

  expects :checklist
  promises :checklist

  executed do |context|
    path = context.project.repository_url

    # Check if directory exists
    context.checklist << "Checking project directory exists..."
    unless Dir.exist?(path)
      context.fail!("Project directory does not exist: #{path}")
      next context
    end

    # Check if it's a git repository
    context.checklist << "Checking if it's a git repository..."
    unless system("git -C #{path} rev-parse --git-dir > /dev/null 2>&1")
      context.fail!("Not a valid git repository: #{path}")
      next context
    end

    # Check if remote origin is GitHub
    context.checklist << "Checking if remote origin is GitHub..."
    remote_url = `git -C #{path} config --get remote.origin.url`.strip
    unless remote_url.include?('github.com')
      context.fail!("Remote origin is not GitHub: #{remote_url}")
      next context
    end

    # Test SSH connectivity to GitHub (timeout after 5 seconds)
    context.checklist << "Checking SSH connectivity to GitHub..."
    ssh_test = system('ssh -o BatchMode=yes -o ConnectTimeout=5 -T git@github.com 2>&1')
    unless ssh_test
      context.fail!("SSH connectivity to GitHub failed")
      next context
    end
  end
end
