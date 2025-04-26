namespace :monitoring do
  desc "Check running docker builds, and delete old ones past 1 hour"
  task check_hanging_builds: :environment do |_, args|
    # Run system command to get all running docker builds longer than 1 hour
    Sys::ProcTable.ps.each do |proc|
      if proc.cmdline.include?("docker buildx") && proc.cmdline.include?("build")
        puts "Detected docker build: #{proc.cmdline}"
      end
    end
  end
end
