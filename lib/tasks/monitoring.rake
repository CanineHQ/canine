namespace :monitoring do
  desc "Check running docker builds, and delete old ones past 1 hour"
  task check_hanging_builds: :environment do |_, args|
    # Run system command to get all running docker builds longer than 1 hour
    docker_builds = Sys::ProcTable.ps.filter do |proc|
      cmdline = proc.cmdline
      cmdline.include?("docker build") || cmdline.include?("docker buildx")
    end

    docker_builds.each do |proc|
      puts "Detected docker build: #{proc.cmdline}"
    end
  end
end
