module AgentComputers
  # Starts `kubectl port-forward` to a pod on a local port kubectl picks itself, and returns once it's listening. Picking
  # the port ourselves (at random) let a tunnel whose kubectl couldn't bind it look ready, because another tunnel was
  # already listening there: the request then reached that other computer, possibly another account's.
  #
  #   forward = KubectlForward.start(kubeconfig_path, namespace, pod, 8080, timeout: 30)
  #   forward.port      # => 49231, bound by this kubectl
  #   forward.alive?    # => whether that kubectl is still running (once it exits, its port can go to another tunnel)
  #   forward.stop
  class KubectlForward
    FORWARDING = /Forwarding from 127\.0\.0\.1:(\d+)/

    class Error < StandardError; end

    attr_reader :pid, :port

    def self.start(kubeconfig_path, namespace, pod, remote_port, timeout:)
      reader, writer = IO.pipe
      pid = spawn({ "KUBECONFIG" => kubeconfig_path },
                  "kubectl", "port-forward", "--address", "127.0.0.1", "-n", namespace, pod, ":#{remote_port}",
                  out: writer, err: writer)
      writer.close
      new(pid, reader, timeout)
    end

    def initialize(pid, reader, timeout)
      @pid = pid
      @waiter = Process.detach(pid)
      @port = read_port(reader, timeout)
      # kubectl logs a line per connection; keep reading so a full pipe never blocks it
      Thread.new { IO.copy_stream(reader, File::NULL) rescue nil; reader.close }
    rescue Error
      stop
      reader.close
      raise
    end

    def alive?
      @waiter.alive?
    end

    def stop
      Process.kill("TERM", @pid) rescue nil
    end

    private

    # kubectl prints "Forwarding from 127.0.0.1:<port> -> <remote>" once it's listening; anything before that, or
    # its exiting, is a failure
    def read_port(reader, timeout)
      deadline = Time.current + timeout
      output = +""
      loop do
        remaining = deadline - Time.current
        raise Error, "kubectl port-forward didn't start in #{timeout} seconds" if remaining <= 0
        next unless reader.wait_readable(remaining)

        output << reader.read_nonblock(4096)
        port = output[FORWARDING, 1]
        return port.to_i if port
      rescue IO::WaitReadable
        next
      rescue EOFError
        raise Error, "kubectl port-forward failed: #{output.strip.presence || "it exited"}"
      end
    end
  end
end
