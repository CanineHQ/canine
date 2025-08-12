module Cli
  class CommandFailedError < StandardError; end
  class RunAndReturnOutput
    def call(command, envs: {})
      command = envs.map { |k, v| "#{k}=#{v}" }.join(" ") + " #{command}"
      output = `#{command.strip}`
      raise CommandFailedError, "Command `#{command}` failed with exit code #{$?.exitstatus}" unless $?.success?
      output
    end
  end

  class RunAndLog
    def initialize(loggable, killable: nil)
      @loggable = loggable
      @killable = killable
      @process = nil
      @monitor_thread = nil
    end

    def call(command, envs: {})
      command = envs.map { |k, v| "#{k}=#{v}" }.join(" ") + " #{command}"

      # Start monitoring thread if killable is provided
      start_monitor_thread if @killable

      Open3.popen3(command.strip) do |stdin, stdout, stderr, wait_thr|
        @process = wait_thr
        stdin.close

        # Create threads to read stdout and stderr
        stdout_thread = Thread.new do
          stdout.each_line { |line| @loggable.info(line.chomp) }
        end

        stderr_thread = Thread.new do
          stderr.each_line { |line| @loggable.info(line.chomp) }
        end

        # Wait for process to complete or be killed
        exit_status = wait_thr.value

        # Ensure output threads complete
        stdout_thread.join
        stderr_thread.join

        # Stop monitoring thread
        stop_monitor_thread

        if @killable&.reload&.killed?
          @loggable.error("Process was killed by user request")
          raise CommandFailedError, "Process was killed"
        elsif exit_status.success?
          @loggable.success("Command succeeded")
        else
          raise CommandFailedError, "Command failed with exit code #{exit_status.exitstatus}"
        end

        exit_status
      end
    ensure
      stop_monitor_thread
    end

    private

    def start_monitor_thread
      @monitor_thread = Thread.new do
        loop do
          sleep 1 # Check every second

          if @killable.reload.killed?
            kill_process if @process
            break
          end
        rescue => e
          Rails.logger.error "Error in kill monitor thread: #{e.message}"
        end
      end
    end

    def stop_monitor_thread
      @monitor_thread&.kill
      @monitor_thread = nil
    end

    def kill_process
      return unless @process&.alive?

      pid = @process.pid
      @loggable.warn("Killing process with PID: #{pid}")

      # First try SIGTERM for graceful shutdown
      Process.kill("TERM", pid)

      # Give it 5 seconds to terminate gracefully
      5.times do
        sleep 1
        return unless @process.alive?
      end

      # If still alive, force kill
      @loggable.warn("Process didn't terminate gracefully, sending SIGKILL")
      Process.kill("KILL", pid)
    rescue Errno::ESRCH
      # Process already dead
      @loggable.info("Process already terminated")
    rescue => e
      @loggable.error("Error killing process: #{e.message}")
    end
  end
end
