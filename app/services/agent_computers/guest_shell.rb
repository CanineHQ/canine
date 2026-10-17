require "net/ssh"
require "shellwords"

module AgentComputers
  # SSH into an agent computer's VM as the desktop user (through a PortForward). Uses the key generated for the
  # computer, which the unattended Omarchy install put in authorized_keys.
  #
  #   GuestShell.open(computer, connection) { |shell| shell.run("hostname") }
  class GuestShell
    class Error < StandardError; end
    CommandFailed = Class.new(Error)

    def self.open(agent_computer, connection, &)
      new(agent_computer, connection).open(&)
    end

    def initialize(agent_computer, connection)
      @computer = agent_computer
      @connection = connection
    end

    def open
      PortForward.open(@computer, @connection, AgentComputer::SSH_PORT) do |port|
        Net::SSH.start("127.0.0.1", AgentComputer::DESKTOP_USER, port:, key_data: [ @computer.ssh_private_key ],
                       keys_only: true, auth_methods: %w[publickey], verify_host_key: :never, non_interactive: true,
                       timeout: 10, keepalive: true, keepalive_interval: 15) do |ssh|
          @ssh = ssh
          yield self
        end
      end
    rescue PortForward::Error, Net::SSH::Exception, Errno::ECONNREFUSED, Errno::ECONNRESET, Errno::EHOSTUNREACH, Timeout::Error, IOError => e
      raise Error, "#{e.class}: #{e.message}"
    end

    # Runs a command (optionally feeding stdin) and returns its combined output; raises unless it exits 0. The
    # environment can hold secrets, so errors name only the command.
    def run(command, stdin: nil, env: {})
      label = command
      command = "#{env.map { |k, v| "#{k}=#{Shellwords.escape(v)}" }.join(" ")} #{command}".strip
      output = +""
      status = nil
      @ssh.open_channel do |channel|
        channel.exec(command) do |_, success|
          raise Error, "couldn't start `#{label}`" unless success

          channel.on_data { |_, data| output << data }
          channel.on_extended_data { |_, _, data| output << data }
          channel.on_request("exit-status") { |_, data| status = data.read_long }
          if stdin
            channel.send_data(stdin)
            channel.eof!
          end
        end
      end
      @ssh.loop
      raise CommandFailed, "`#{label}` exited #{status}:\n#{output.lines.last(40).join}" unless status&.zero?

      output
    end
  end
end
