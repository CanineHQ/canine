module Cli
  class CommandFailedError < StandardError; end
  class RunAndReturnOutput
    def call(command, envs: {})
      command = envs.map { |k, v| "#{k}=#{v}" }.join(" ") + " #{command}"
      output = `#{command}`
      output
    end
  end

  class RunAndLog
    def initialize(loggable)
      @loggable = loggable
    end

    def call(command, envs: {})
      command = envs.map { |k, v| "#{k}=#{v}" }.join(" ") + " #{command}"
      @loggable.info("`#{command.strip}`")
      Open3.popen3(command) do |stdin, stdout, stderr, wait_thr|
        stdin.close
        out_reader = Thread.new do
          stdout.each_line { |line| @loggable.info(line.chomp) }
        end
        err_reader = Thread.new do
          stderr.each_line { |line| @loggable.info(line.chomp) }
        end

        out_reader.join
        err_reader.join

        exit_status = wait_thr.value
        if exit_status.success?
          @loggable.info("Command succeeded")
        else
          raise CommandFailedError, "Command failed with exit code #{exit_status.exitstatus}"
        end
        exit_status
      end
    end
  end

end