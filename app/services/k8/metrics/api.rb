module K8::Metrics::Api
  class Node
    extend StorageHelper
    def self.ls(connection, with_namespaces: true)
      cluster = connection.cluster
      # Here, run kubectl top nodes
      kubectl = K8::Kubectl.new(connection)
      response = kubectl.call("top nodes")
      parsed_data = parse_output(response)
      #  get --raw /apis/metrics.k8s.io/v1beta1/nodes/#{node}
      # Infer total memory
      parsed_data.map do |data|
        capacities = YAML.safe_load(kubectl.call("get node/#{data[:name]} -o wide -o yaml"))

        total_memory = memory_to_integer(capacities["status"]["allocatable"]["memory"])
        total_cpu = compute_to_integer(capacities["status"]["allocatable"]["cpu"])

        used_memory = memory_to_integer(data[:memory_bytes])
        cpu_cores = compute_to_integer(data[:cpu_cores])

        node = Node.new(
          name: data[:name],
          cpu_cores:,
          total_cpu:,
          used_memory:,
          total_memory:
        )
        if with_namespaces
          cluster.projects.each do |project|
            begin
              node.namespaces[project.name] = K8::Metrics::Api::Pod.fetch(connection, project.name)
            rescue StandardError => e
              Rails.logger.error("Failed to fetch pod metrics for project #{project.name}: #{e.message}")
            end
          end
          cluster.add_ons.each do |add_on|
            begin
              node.namespaces[add_on.name] = K8::Metrics::Api::Pod.fetch(connection, add_on.name)
            rescue StandardError => e
              Rails.logger.error("Failed to fetch pod metrics for add-on #{add_on.name}: #{e.message}")
            end
          end
        end
        node
      end
    end

    def self.parse_output(output)
      # Define a regex pattern to capture the required fields
      pattern = /(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)/

      # Split the data into lines and remove the header line
      lines = output.split("\n")
      if lines.length <= 1
        return []
      end
      lines.shift # Remove the header line

      # Parse each line and create a hash for each node
      lines.map do |line|
        match = pattern.match(line)
        if match
          {
            name: match[1],
            cpu_cores: match[2],
            cpu_percent: match[3],
            memory_bytes: match[4],
            memory_percent: match[5]
          }
        else
          nil
        end
      end.compact
    end

    attr_reader :name, :cpu_cores, :total_cpu, :used_memory, :total_memory, :namespaces
    def initialize(
      name:,
      cpu_cores:,
      total_cpu:,
      used_memory:,
      total_memory:
    )
      @name = name
      @cpu_cores = cpu_cores
      @total_cpu = total_cpu
      @used_memory = used_memory
      @total_memory = total_memory
      @namespaces = {}
    end

    def cpu_percent
      (cpu_cores / total_cpu.to_f * 100).round(2)
    end

    def memory_percent
      (used_memory / total_memory.to_f * 100).round(2)
    end
  end

  class Pod
    extend StorageHelper

    def self.fetch(connection, namespace)
      kubectl = K8::Kubectl.new(connection)
      response = kubectl.call("top pods -n #{namespace}")
      parsed_data = parse_output(response)
      parsed_data.map do |data|
        Pod.new(
          name: data[:name],
          cpu: compute_to_integer(data[:cpu]),
          memory: memory_to_integer(data[:memory])
        )
      end
    end

    def self.parse_output(output)
      lines = output.split("\n")
      if lines.length <= 1
        return []
      end
      headers = lines.shift.split(/\s+/)

      lines.map do |line|
        values = line.split(/\s+/, 3)
        {
          name: values[0],
          cpu: values[1],
          memory: values[2]
        }
      end
    end

    attr_reader :name, :cpu, :memory
    def initialize(
      name:,
      cpu:,
      memory:
    )
      @name = name
      @cpu = cpu
      @memory = memory
    end
  end
end
