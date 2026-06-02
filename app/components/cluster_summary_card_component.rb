class ClusterSummaryCardComponent < ViewComponent::Base
  include StorageHelper

  attr_reader :nodes, :version, :error

  def initialize(nodes:, version: nil, error: nil)
    @nodes = nodes
    @version = version
    @error = error
  end

  def total_cpu
    nodes.sum(&:total_cpu)
  end

  def total_memory
    nodes.sum(&:total_memory)
  end

  def used_cpu
    nodes.sum(&:cpu_cores)
  end

  def used_memory
    nodes.sum(&:used_memory)
  end

  def cpu_percent
    return 0 if total_cpu.zero?
    (used_cpu / total_cpu.to_f * 100).round(1)
  end

  def memory_percent
    return 0 if total_memory.zero?
    (used_memory / total_memory.to_f * 100).round(1)
  end
end
