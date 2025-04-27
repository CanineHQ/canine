namespace :monitoring do
  MAX_BUILD_AGE = 1.hour

  def starttime_to_datetime(proc_entry)
    # Read system uptime
    uptime_seconds = File.read('/proc/uptime').split[0].to_f

    # Calculate boot time
    boot_time = Time.now - uptime_seconds

    # Get clock ticks per second
    clock_ticks_per_second = `getconf CLK_TCK`.to_i

    # Calculate seconds since boot when the process started
    starttime_seconds = proc_entry.starttime.to_f / clock_ticks_per_second

    # Add to boot time and convert to DateTime
    start_time = boot_time + starttime_seconds

    DateTime.parse(start_time.utc.iso8601)
  end

  desc "Check running docker builds, and delete old ones past 1 hour"
  task check_hanging_builds: :environment do |_, args|
    # Run system command to get all running docker builds longer than 1 hour
    docker_builds = Sys::ProcTable.ps.filter do |proc|
      cmdline = proc.cmdline
      cmdline.include?("docker build") || cmdline.include?("docker buildx")
    end.each do |proc|
      if proc.respond_to?(:starttime) && proc.starttime
        starttime = starttime_to_datetime(proc)
        if Time.now.to_i - starttime.to_i > MAX_BUILD_AGE
          puts "Killing PID #{proc.pid} started #{starttime}"
          Process.kill("SIGKILL", proc.pid)
        end
      end
    end
  end
end
