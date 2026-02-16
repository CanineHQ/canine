require "pty"
require "shellwords"

class PodShellChannel < ApplicationCable::Channel
  def subscribed
    token = ShellToken.active.find_by(token: params[:token])

    if token.nil? || token.user_id != current_user.id
      reject
      return
    end

    @shell_token = token
    @shell_token.destroy!

    stream_from stream_name
  end

  def receive(data)
    if data["type"] == "resize"
      if @master
        resize_pty(data["cols"].to_i, data["rows"].to_i)
      else
        start_shell(data["cols"].to_i, data["rows"].to_i)
      end
    elsif data["type"] == "input" && @master
      @master.write(data["data"])
    end
  rescue Errno::EIO, IOError
    stop_shell
  end

  def unsubscribed
    stop_shell
  end

  private

  def stream_name
    "pod_shell_#{@shell_token.token}"
  end

  def start_shell(cols = 80, rows = 24)
    connection = K8::Connection.new(@shell_token.cluster, current_user)
    kubeconfig = connection.kubeconfig
    kubeconfig_hash = kubeconfig.is_a?(String) ? JSON.parse(kubeconfig) : kubeconfig
    kubeconfig_hash = K8::Kubeconfig.apply_tls_settings(kubeconfig_hash, connection.cluster.skip_tls_verify)

    @kubeconfig_file = Tempfile.new([ "kubeconfig", ".yaml" ])
    @kubeconfig_file.write(kubeconfig_hash.to_yaml)
    @kubeconfig_file.flush

    container_flag = @shell_token.container.present? ? " -c #{Shellwords.shellescape(@shell_token.container)}" : ""
    command = "KUBECONFIG=#{Shellwords.shellescape(@kubeconfig_file.path)} kubectl exec -it -n #{Shellwords.shellescape(@shell_token.namespace)}#{container_flag} #{Shellwords.shellescape(@shell_token.pod_name)} -- /bin/sh -c 'export TERM=xterm-256color; if command -v bash >/dev/null 2>&1; then exec bash; else exec sh; fi'"

    @master, slave = PTY.open
    @master.winsize = [ rows, cols ]
    @pid = spawn({ "TERM" => "xterm-256color" }, command, in: slave, out: slave, err: slave)
    slave.close

    @reader_thread = Thread.new do
      loop do
        data = @master.read_nonblock(16384)
        transmit({ type: "output", data: data.force_encoding("UTF-8").scrub("") })
      rescue IO::WaitReadable
        IO.select([ @master ], nil, nil, 0.1)
        retry
      rescue Errno::EIO, IOError
        break
      rescue => e
        Rails.logger.error("PodShellChannel read error: #{e.message}")
      end

      transmit({ type: "exit" })
      stop_shell
    end
  rescue => e
    transmit({ type: "error", data: "Failed to start shell: #{e.message}" })
    reject
  end

  def stop_shell
    if @reader_thread && @reader_thread != Thread.current
      @reader_thread.kill
    end
    @reader_thread = nil

    if @pid
      begin
        # Try to reap if already exited, otherwise send TERM
        result = Process.waitpid(@pid, Process::WNOHANG)
        unless result
          Process.kill("TERM", @pid)
          Process.waitpid(@pid)
        end
      rescue Errno::ESRCH, Errno::ECHILD
        # Process already exited and reaped
      end
    end
    @pid = nil

    @master&.close
    @master = nil

    @kubeconfig_file&.close
    @kubeconfig_file&.unlink
    @kubeconfig_file = nil
  end

  def resize_pty(cols, rows)
    return unless @master

    @master.winsize = [ rows, cols ]
  rescue Errno::EIO, IOError
    # PTY already closed
  end
end
